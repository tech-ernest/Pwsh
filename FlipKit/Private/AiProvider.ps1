function Get-FlipAiConfig {
    <#
        Resolves the AI provider from config. Preferred shape:
          "ai": { "provider": "ollama|openai|anthropic", "model": "...", "baseUrl": "...", "apiKey": "..." }
        Back-compat: an "anthropic" section with an apiKey acts as provider=anthropic.
    #>
    $cfg = Get-FlipConfig
    if ($cfg.PSObject.Properties['ai'] -and $cfg.ai.provider) { return $cfg.ai }
    if ($cfg.PSObject.Properties['anthropic'] -and $cfg.anthropic.apiKey) {
        $model = if ($cfg.anthropic.PSObject.Properties['model'] -and $cfg.anthropic.model) { $cfg.anthropic.model } else { 'claude-opus-4-8' }
        return [pscustomobject]@{ provider = 'anthropic'; apiKey = $cfg.anthropic.apiKey; model = $model; baseUrl = '' }
    }
    throw 'No AI provider configured. Free option: install Ollama from ollama.com, run "ollama pull llama3.1:8b", then add to config/settings.json: "ai": { "provider": "ollama", "model": "llama3.1:8b" }'
}

function Invoke-FlipAiHttpPost {
    <#
        JSON POST for AI providers. Prefers curl.exe (proven reliable on
        Windows where Invoke-RestMethod header handling has bitten us);
        falls back to Invoke-RestMethod. Body goes via a temp file to avoid
        command-line quoting/length limits.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{},
        [Parameter(Mandatory)][string]$BodyJson,
        [int]$TimeoutSec = 300
    )

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        $tmp = [IO.Path]::GetTempFileName()
        # Response also via temp file: stdout captured through the console gets
        # decoded with the console codepage on Windows, garbling non-ASCII (£, é…).
        $outFile = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllText($tmp, $BodyJson, [Text.UTF8Encoding]::new($false))
            $args = @('-sS', '--fail-with-body', '--max-time', $TimeoutSec, '-X', 'POST', '-H', 'Content-Type: application/json')
            foreach ($k in $Headers.Keys) { $args += @('-H', "${k}: $($Headers[$k])") }
            $args += @('--data-binary', "@$tmp", '-o', $outFile, $Uri)

            & $curl.Source @args 2>$null | Out-Null
            $out = [IO.File]::ReadAllText($outFile, [Text.Encoding]::UTF8)
            if ($LASTEXITCODE -ne 0) {
                $apiMessage = try { ($out | ConvertFrom-Json).error.message } catch { $null }
                if ($apiMessage) { throw "AI API error: $apiMessage" }
                throw "AI request failed (curl exit $LASTEXITCODE): $($out.Substring(0, [math]::Min(300, $out.Length)))"
            }
            return $out | ConvertFrom-Json
        }
        finally { Remove-Item $tmp, $outFile -ErrorAction SilentlyContinue }
    }

    try {
        Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers `
            -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes($BodyJson)) -TimeoutSec $TimeoutSec
    }
    catch {
        $apiMessage = try { ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { $null }
        if ($apiMessage) { throw "AI API error: $apiMessage" }
        throw
    }
}

function Invoke-FlipAi {
    <#
        Provider-agnostic chat completion. Takes a system prompt, a
        conversation (array of @{role;content}), and an optional JSON schema
        for structured replies. Returns the reply text.

        Providers:
          ollama    - free, local (ollama.com). Schema enforced via Ollama's
                      "format" grammar constraint.
          openai    - any OpenAI-compatible endpoint: Groq / OpenRouter /
                      Gemini free tiers, LM Studio, etc. Needs baseUrl (+ apiKey
                      for hosted). Schema requested via json mode + prompt.
          anthropic - Claude API (paid). Schema via structured outputs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$System,
        [Parameter(Mandatory)][array]$Messages,
        [hashtable]$JsonSchema
    )

    $ai = Get-FlipAiConfig

    switch ($ai.provider) {

        'ollama' {
            $baseUrl = if ($ai.PSObject.Properties['baseUrl'] -and $ai.baseUrl) { $ai.baseUrl.TrimEnd('/') } else { 'http://localhost:11434' }
            $body = @{
                model    = $ai.model
                stream   = $false
                messages = @(@{ role = 'system'; content = $System }) + @($Messages | ForEach-Object { @{ role = $_.role; content = $_.content } })
            }
            if ($JsonSchema) { $body.format = $JsonSchema }

            try {
                $resp = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/chat" `
                    -ContentType 'application/json; charset=utf-8' `
                    -Body ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 14))) `
                    -TimeoutSec 600
            }
            catch {
                if ($_.Exception.Message -match 'refused|actively|connect') {
                    throw "Can't reach Ollama at $baseUrl - is it running? Install from ollama.com, then: ollama pull $($ai.model)"
                }
                throw
            }
            return $resp.message.content
        }

        'openai' {
            if (-not ($ai.PSObject.Properties['baseUrl'] -and $ai.baseUrl)) {
                throw 'The openai provider needs "baseUrl" in the ai config (e.g. https://api.groq.com/openai for Groq''s free tier).'
            }
            $sys = $System
            if ($JsonSchema) {
                $sys += "`n`nYou MUST respond with a single JSON object (no prose, no code fences) matching this JSON schema:`n" + ($JsonSchema | ConvertTo-Json -Depth 14)
            }
            $body = @{
                model    = $ai.model
                messages = @(@{ role = 'system'; content = $sys }) + @($Messages | ForEach-Object { @{ role = $_.role; content = $_.content } })
            }
            if ($JsonSchema) { $body.response_format = @{ type = 'json_object' } }

            $headers = @{}
            if ($ai.PSObject.Properties['apiKey'] -and $ai.apiKey) { $headers.Authorization = "Bearer $($ai.apiKey.Trim())" }

            $resp = Invoke-FlipAiHttpPost -Uri "$($ai.baseUrl.TrimEnd('/'))/v1/chat/completions" `
                -Headers $headers -BodyJson ($body | ConvertTo-Json -Depth 14)
            return $resp.choices[0].message.content
        }

        'anthropic' {
            $body = @{
                model      = $ai.model
                max_tokens = 16000
                thinking   = @{ type = 'adaptive' }
                system     = $System
                messages   = @($Messages | ForEach-Object { @{ role = $_.role; content = $_.content } })
            }
            if ($JsonSchema) { $body.output_config = @{ format = @{ type = 'json_schema'; schema = $JsonSchema } } }

            $resp = Invoke-FlipAiHttpPost -Uri 'https://api.anthropic.com/v1/messages' `
                -Headers @{ 'x-api-key' = $ai.apiKey.Trim(); 'anthropic-version' = '2023-06-01' } `
                -BodyJson ($body | ConvertTo-Json -Depth 14)
            if ($resp.stop_reason -eq 'refusal') { return '(The model declined this request.)' }
            return (@($resp.content) | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join "`n"
        }

        default { throw "Unknown ai.provider '$($ai.provider)' - use ollama, openai, or anthropic." }
    }
}

function ConvertFrom-FlipAiJson {
    <#
        Tolerant JSON parse for model output: strips code fences and leading
        prose that smaller local models sometimes add around the JSON.
    #>
    param([Parameter(Mandatory)][string]$Text)

    $t = $Text.Trim()
    $t = $t -replace '(?s)^```(?:json)?\s*', '' -replace '(?s)\s*```$', ''
    # If prose surrounds the object, cut from the first { to the last }.
    $first = $t.IndexOf('{'); $last = $t.LastIndexOf('}')
    if ($first -gt 0 -and $last -gt $first) { $t = $t.Substring($first, $last - $first + 1) }
    $t | ConvertFrom-Json
}
