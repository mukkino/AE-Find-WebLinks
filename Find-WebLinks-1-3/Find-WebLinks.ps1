#requires -Version 5.1

# Find-WebLinks.ps1 - 1.3
# Author: Fabio Lichinchi (mukka)
# 
# THE UNLICENSE
# This is free and unencumbered software released into the public domain.
# Anyone is free to copy, modify, publish, use, compile, sell, or distribute
# this software, either in source code form or as a compiled binary, for any
# purpose, commercial or non-commercial, and by any means.
# In jurisdictions that recognize copyright laws, the author or authors of this
# software dedicate any and all copyright interest in the software to the public
# domain. We make this dedication for the benefit of the public at large and to
# the detriment of our heirs and successors. We intend this dedication to be an
# overt act of relinquishment in perpetuity of all present and future rights to
# this software under copyright law.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# For more information, please refer to: https://unlicense.org/
# -------------------------------------------------------
# BUGS & FEATURE REQUESTS
# Bug reports and feature requests are appreciated!
# Please visit the project's page, which you can find at:
#     https://alterego.cc
# -------------------------------------------------------
# DISCLAIMER
# Before diving into the code, a small reality check.
# You may find that my coding style, architecture choices, naming conventions,
# error handling, formatting, comments, lack of comments, or any number of other
# technical or aesthetic decisions do not align with your refined engineering
# sensibilities or personal definition of perfection. That's fine.
# This project exists because I built it for myself, to solve problems I
# personally had. I'm simply making it available in case someone else finds it
# useful.
# If you like it, use it. If you don't like it, don't use it. If you think you
# can do better, by all means go ahead and write your own version.
# What you should not do is show up with unsolicited lectures, passive-aggressive
# nitpicking, or clever little remarks about how you would have done things
# differently. Those contributions add exactly zero value.
# So here is the simple rule:
# Use it if it helps you. Ignore it if it doesn't. And if your main intention is
# to complain, critique for sport, or showcase your superior taste -- please take
# that energy somewhere else.
# That said, if you actually want to help in a constructive way -- improvements,
# fixes, ideas, pull requests, or thoughtful discussion -- then you're absolutely
# welcome. I'm always happy to collaborate with people who bring solutions
# instead of attitude.
# Thank you, and enjoy the code.

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Source,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$SearchPattern,

    [Parameter(Mandatory = $false)]
    [string[]]$SearchPatterns,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Any", "All")]
    [string]$SearchMode = "Any",

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateSet("Append", "New")]
    [string]$Mode = "Append",

    [Parameter(Mandatory = $false, Position = 4)]
    [ValidateSet("Url", "File")]
    [string]$SourceType = "Url",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$RetryCount = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 86400)]
    [int]$WaitSeconds = 30,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 120,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 86400)]
    [int]$DelaySeconds = 5,

    [Parameter(Mandatory = $false)]
    [bool]$SecondFetch = $true,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 86400)]
    [int]$SecondFetchWait = 5,

    [Parameter(Mandatory = $false)]
    [switch]$KeepDuplicates,

    [Parameter(Mandatory = $false)]
    [bool]$NoDuplicates = $true,

    [Parameter(Mandatory = $false)]
    [string[]]$BlacklistFile,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Input", "Output", "Both")]
    [string]$BlacklistScope = "Both",

    [Parameter(Mandatory = $false)]
    [string]$LogCsv,

    [Parameter(Mandatory = $false)]
    [string]$FailedUrlFile,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Append", "New")]
    [string]$LogMode = "Append",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Append", "New")]
    [string]$FailedUrlMode = "Append"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Show-Usage {
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\Find-WebLinks.ps1 <Source> <SearchPattern> <OutputFile> [Mode] [SourceType] [options]"
    Write-Host "  .\Find-WebLinks.ps1 <Source> -SearchPatterns <patterns> -OutputFile <OutputFile> [options]"
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  Source          What to scrape. This is either a URL or a text file path,"
    Write-Host "                  depending on SourceType (see below)."
    Write-Host "  SearchPattern   Main wildcard pattern to match against extracted links."
    Write-Host "                  Optional if -SearchPatterns is used."
    Write-Host "                  Use * for any characters. Example: *sport* matches any"
    Write-Host "                  link containing the word sport."
    Write-Host "  OutputFile      Path to the file where matched links are saved."
    Write-Host ""
    Write-Host "  Additional search options:"
    Write-Host "  -SearchPatterns <p1>,<p2>   One or more wildcard patterns. Can be used alone or with SearchPattern."
    Write-Host "  -SearchMode <Any|All>      Any = match if any pattern hits (default). All = must match every pattern."
    Write-Host ""
    Write-Host "Mode (optional, default: Append):"
    Write-Host "  New       Create or overwrite the output file, then write matched links."
    Write-Host "  Append    Add matched links to the end of the output file. If the file"
    Write-Host "            does not exist it is created."
    Write-Host ""
    Write-Host "SourceType (optional, default: Url):"
    Write-Host "  Url       Source is a single web page URL. The script fetches that one"
    Write-Host "            page and extracts all links from it."
    Write-Host "  File      Source is a text file containing a list of URLs, one per line."
    Write-Host "            The script reads every URL from the file, deduplicates them,"
    Write-Host "            fetches each page one by one, and extracts links from all of"
    Write-Host "            them. Results are written to the output file after each page."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -RetryCount <n>            Number of retry attempts per URL (default: 3)"
    Write-Host "  -WaitSeconds <n>           Seconds to wait between retries of the same URL (default: 30)"
    Write-Host "  -TimeoutSeconds <n>        HTTP timeout per request attempt (default: 120)"
    Write-Host "  -DelaySeconds <n>          Seconds to wait between different URLs in File mode (default: 5)"
    Write-Host "  -SecondFetch <bool>        Fetch each URL twice, keep the larger response (default: true)"
    Write-Host "  -SecondFetchWait <n>       Seconds to wait before the second fetch (default: 5)"
    Write-Host "  -KeepDuplicates            Keep duplicate matches found within the same page"
    Write-Host "  -NoDuplicates <bool>       Skip links already written or in output file (default: true)"
    Write-Host "  -BlacklistFile <f>         One or more text files of exact URLs to exclude, one per line"
    Write-Host "  -BlacklistScope <scope>    Where blacklist applies: Input, Output, or Both (default: Both)"
    Write-Host "  -LogCsv <f>                CSV file to log per-URL stats (timestamp, status, counts, errors)"
    Write-Host "  -FailedUrlFile <f>         File where failed source URLs and errors are written (tab-separated)"
    Write-Host "  -LogMode <Append|New>      Append to or overwrite the CSV log file (default: Append)"
    Write-Host "  -FailedUrlMode <Append|New> Append to or overwrite the failed URL file (default: Append)"
    Write-Host ""
    Write-Host "Examples -- single URL (SourceType = Url):"
    Write-Host ""
    Write-Host "  Fetch one page, find sport links, write to a new file:"
    Write-Host "  .\Find-WebLinks.ps1 `"https://www.bbc.co.uk/news`" `"*sport*`" `"C:\Temp\bbc-links.txt`" New"
    Write-Host ""
    Write-Host "  Fetch one page, find politics links, append to the same file:"
    Write-Host "  .\Find-WebLinks.ps1 `"https://www.bbc.co.uk/news`" `"*politics*`" `"C:\Temp\bbc-links.txt`""
    Write-Host ""
    Write-Host "  Same but with custom retry settings:"
    Write-Host "  .\Find-WebLinks.ps1 `"bbc.co.uk/news`" `"*weather*`" `".\bbc-links.txt`" -WaitSeconds 60 -RetryCount 5"
    Write-Host ""
    Write-Host "Examples -- list of URLs (SourceType = File):"
    Write-Host ""
    Write-Host "  Read URLs from a text file, fetch every page, find sport links:"
    Write-Host "  .\Find-WebLinks.ps1 `"C:\Temp\urls.txt`" `"*sport*`" `"C:\Temp\matched.txt`" New File"
    Write-Host ""
    Write-Host "  Same but append to existing output:"
    Write-Host "  .\Find-WebLinks.ps1 `"C:\Temp\urls.txt`" `"*news*`" `"C:\Temp\matched.txt`" Append File"
    Write-Host ""
    Write-Host "Examples -- multiple search patterns:"
    Write-Host ""
    Write-Host "  Match links containing news OR sport OR weather (Any mode, default):"
    Write-Host "  .\Find-WebLinks.ps1 `"bbc.co.uk`" `"*news*`" `"out.txt`" -SearchPatterns `"*sport*`",`"*weather*`""
    Write-Host ""
    Write-Host "  Match links containing BOTH news AND 2026 (All mode):"
    Write-Host "  .\Find-WebLinks.ps1 `"bbc.co.uk`" `"*news*`" `"out.txt`" -SearchPatterns `"*2026*`" -SearchMode All"
    Write-Host ""
    Write-Host "  Use only -SearchPatterns, without a main positional SearchPattern:"
    Write-Host "  .\Find-WebLinks.ps1 `"bbc.co.uk`" -SearchPatterns `"*news*`",`"*sport*`" -OutputFile `"out.txt`""
    Write-Host ""
    Write-Host "  With CSV log and failed URL tracking (fresh log files, append output):"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" `"*news*`" `"matched.txt`" Append File -LogCsv `"run-log.csv`" -LogMode New -FailedUrlFile `"failed.txt`" -FailedUrlMode New"
    Write-Host ""
    Write-Host "Examples -- blacklist:"
    Write-Host ""
    Write-Host "  Blacklist applied to both input and output (default):"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" `"*`" `"out.txt`" Append File -BlacklistFile `"blocked.txt`""
    Write-Host ""
    Write-Host "  Blacklist applied only to extracted output links:"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" `"*`" `"out.txt`" Append File -BlacklistFile `"blocked.txt`" -BlacklistScope Output"
    Write-Host ""
    Write-Host "  Blacklist applied only to input URLs (skip fetching, keep in output):"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" `"*`" `"out.txt`" Append File -BlacklistFile `"blocked.txt`" -BlacklistScope Input"
    Write-Host ""
    Write-Host "  Multiple blacklist files:"
    Write-Host "  .\Find-WebLinks.ps1 `"bbc.co.uk`" `"*`" `"out.txt`" -BlacklistFile `"ads.txt`",`"tracking.txt`""
    Write-Host ""
    Write-Host "Disabling defaults:"
    Write-Host "  -NoDuplicates:`$false     Allow links already written/in output to be written again"
    Write-Host "  -KeepDuplicates          Also keep repeated matches from the same page"
    Write-Host "  -SecondFetch:`$false      Fetch each URL only once"
    Write-Host ""
    Write-Host "BlacklistFile and BlacklistScope:"
    Write-Host "  One or more text files of exact URLs to exclude, one per line."
    Write-Host "  Only exact URL matches are blocked (case-insensitive, trailing-slash"
    Write-Host "  and fragment ignored). A blacklist entry of https://facebook.com will"
    Write-Host "  NOT block https://facebook.com/some/page -- only the exact URL."
    Write-Host ""
    Write-Host "  BlacklistScope controls where the blacklist is applied:"
    Write-Host "    Input   Skip blacklisted URLs from the source list before fetching"
    Write-Host "    Output  Remove blacklisted URLs from extracted/matched results only"
    Write-Host "    Both    Do both (default)"
    Write-Host ""
    Write-Host "Note:"
    Write-Host "  This script downloads the raw HTTP response. It does NOT execute"
    Write-Host "  JavaScript, so content rendered entirely by client-side JS (React,"
    Write-Host "  Vue, Angular SPAs, etc.) will not be visible. It does extract URLs"
    Write-Host "  embedded in <script> blocks, JSON, CSS, and <noscript> fallbacks."
    Write-Host ""
}

if (
    [string]::IsNullOrWhiteSpace($Source) -or
    (
        [string]::IsNullOrWhiteSpace($SearchPattern) -and
        (
            -not $SearchPatterns -or
            @($SearchPatterns | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0
        )
    ) -or
    [string]::IsNullOrWhiteSpace($OutputFile)
) {
    Show-Usage
    exit 0
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Convert-WildcardToRegex {
    param([string]$Pattern)

    $escaped = [regex]::Escape($Pattern)
    $regex   = $escaped -replace '\\\*', '.*'
    return "^$regex$"
}

function Get-EffectiveSearchPatterns {
    $patterns = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($SearchPattern)) {
        [void]$patterns.Add($SearchPattern.Trim())
    }

    if ($SearchPatterns) {
        foreach ($pattern in $SearchPatterns) {
            if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                [void]$patterns.Add($pattern.Trim())
            }
        }
    }

    return @($patterns | Select-Object -Unique)
}

function Test-LinkMatchesSearch {
    param(
        [string]$Link,
        [string[]]$RegexList,
        [string]$Mode
    )

    if ([string]::IsNullOrWhiteSpace($Link)) { return $false }

    if ($Mode -eq "All") {
        foreach ($regex in $RegexList) {
            if ($Link -notmatch $regex) {
                return $false
            }
        }
        return $true
    }

    foreach ($regex in $RegexList) {
        if ($Link -match $regex) {
            return $true
        }
    }

    return $false
}

# Normalise a link for "same enough" duplicate comparison.
# Strips fragment (#...), trailing slash, and lowercases.
function Get-LinkKey {
    param([string]$Link)

    if ([string]::IsNullOrWhiteSpace($Link)) { return "" }

    try {
        $uri = [uri]$Link
        $builder = [System.UriBuilder]::new($uri)
        $builder.Fragment = ""
        return $builder.Uri.AbsoluteUri.TrimEnd('/').ToLowerInvariant()
    }
    catch {
        return $Link.Trim().TrimEnd('/').ToLowerInvariant()
    }
}

# Decode JS-escaped URLs (\/ and \u002F).
function Decode-JsUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }

    return $Value `
        -replace '\\/', '/' `
        -replace '\\u002[Ff]', '/'
}

function Normalize-Link {
    param(
        [string]$Link,
        [uri]$BaseUri = $null
    )

    if ([string]::IsNullOrWhiteSpace($Link)) { return $null }

    $link = [System.Net.WebUtility]::HtmlDecode($Link.Trim())
    $link = $link -replace '[\x00-\x1F\x7F]', ''
    $link = $link.Trim()

    if ([string]::IsNullOrWhiteSpace($link)) { return $null }

    $link = $link.TrimEnd('.', ',', ';', ':', ')', ']', '}', '"', "'")

    if ([string]::IsNullOrWhiteSpace($link)) { return $null }

    # Ignore non-web protocols
    if ($link -match '^(mailto|tel|javascript|data|ftp|file):') { return $null }

    # Ignore page anchors
    if ($link.StartsWith("#")) { return $null }

    # Already absolute http/https
    if ($link -match '^https?://') { return $link }

    # Protocol-relative
    if ($link -match '^//') {
        if ($null -ne $BaseUri) { return "$($BaseUri.Scheme):$link" }
        return "https:$link"
    }

    # Bare www
    if ($link -match '^www\.') { return "https://$link" }

    # Bare domain
    if ($link -match '^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:\d+)?(/.*)?$') {
        return "https://$link"
    }

    # Relative link
    if ($null -ne $BaseUri) {
        try {
            $absolute = [uri]::new($BaseUri, $link)
            if ($absolute.Scheme -match '^https?$') { return $absolute.AbsoluteUri }
        }
        catch { return $null }
    }

    return $null
}

function Test-BlacklistAppliesToInput {
    return ($BlacklistScope -eq "Input" -or $BlacklistScope -eq "Both")
}

function Test-BlacklistAppliesToOutput {
    return ($BlacklistScope -eq "Output" -or $BlacklistScope -eq "Both")
}

function Test-IsBlacklisted {
    param(
        [string]$Url,
        [System.Collections.Generic.HashSet[string]]$BlacklistSet
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    if ($null -eq $BlacklistSet -or $BlacklistSet.Count -eq 0) { return $false }

    return $BlacklistSet.Contains((Get-LinkKey $Url))
}

# ---------------------------------------------------------------------------
# Invoke-WebRequestWithRetry
#   - Retries up to $MaxRetries times on failure
#   - Waits $WaitSec between each retry attempt
#   - Uses a WebRequestSession to accumulate cookies across redirects
#   - Follows <meta http-equiv="refresh"> redirects
#   - When $DoSecondFetch is true, silently fetches the page a second time
#     (after $SecondWait seconds) using the same session and keeps whichever
#     response is larger. This helps with cookie-walls and session-gated
#     pages. It does NOT execute JavaScript or wait for client-side rendering.
# ---------------------------------------------------------------------------

function Invoke-WebRequestWithRetry {
    param(
        [string]$Url,
        [int]$MaxRetries,
        [int]$WaitSec,
        [int]$Timeout,
        [bool]$DoSecondFetch,
        [int]$SecondWait
    )

    if ($Url -notmatch '^https?://') { $Url = "https://$Url" }

    $session  = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    $headers = @{
        "Accept"           = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        "Accept-Language"  = "en-GB,en;q=0.9"
        "Accept-Encoding"  = "identity"            # avoid gzip issues on older PS
        "Cache-Control"    = "no-cache"
    }

    $currentUrl    = $Url
    $maxRedirects  = 10
    $redirectsDone = 0

    :redirectLoop while ($redirectsDone -lt $maxRedirects) {

        $lastError = $null

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {

            try {
                Write-Host "  Attempt $attempt of $MaxRetries -- GET $currentUrl"

                $response = Invoke-WebRequest `
                    -Uri $currentUrl `
                    -WebSession $session `
                    -Headers $headers `
                    -UseBasicParsing `
                    -MaximumRedirection 10 `
                    -TimeoutSec $Timeout `
                    -ErrorAction Stop

                # Silent second fetch: wait, re-request with same session,
                # keep the larger body. No extra console output.
                if ($DoSecondFetch) {
                    if ($SecondWait -gt 0) {
                        Start-Sleep -Seconds $SecondWait
                    }
                    try {
                        $response2 = Invoke-WebRequest `
                            -Uri $currentUrl `
                            -WebSession $session `
                            -Headers $headers `
                            -UseBasicParsing `
                            -MaximumRedirection 10 `
                            -TimeoutSec $Timeout `
                            -ErrorAction Stop

                        if ($response2.Content.Length -gt $response.Content.Length) {
                            $response = $response2
                        }
                    }
                    catch {
                        # Second fetch failed silently -- use first response
                    }
                }

                # Check for <meta http-equiv="refresh"> redirect
                $metaRefresh = [regex]::Match(
                    $response.Content,
                    '(?i)<meta[^>]+http-equiv\s*=\s*["'']refresh["''][^>]+content\s*=\s*["'']\s*\d+\s*;\s*url\s*=\s*(?<url>[^"''>]+)',
                    [System.Text.RegularExpressions.RegexOptions]::Singleline
                )
                if ($metaRefresh.Success) {
                    $nextUrl = $metaRefresh.Groups["url"].Value.Trim()
                    $nextUrl = Normalize-Link -Link $nextUrl -BaseUri ([uri]$currentUrl)
                    if ($nextUrl -and $nextUrl -ne $currentUrl) {
                        Write-Host "  Following meta-refresh redirect -> $nextUrl"
                        $currentUrl = $nextUrl
                        $redirectsDone++
                        continue redirectLoop
                    }
                }

                return $response
            }
            catch {
                $lastError = $_
                Write-Host "  Attempt $attempt failed: $($_.Exception.Message)"

                if ($attempt -lt $MaxRetries) {
                    Write-Host "  Retrying in $WaitSec second(s) ..."
                    Start-Sleep -Seconds $WaitSec
                }
            }
        }

        # All retries exhausted for this URL
        throw "All $MaxRetries attempt(s) failed for $currentUrl. Last error: $($lastError.Exception.Message)"
    }

    throw "Too many meta-refresh redirects (max $maxRedirects)."
}

# ---------------------------------------------------------------------------
# Extract every link-like thing from the downloaded HTML.
#
# This is a best-effort scrape of the raw HTTP response body. It does NOT
# execute JavaScript, so links created purely by client-side JS will not
# appear. It does dig into <script> blocks, JSON strings, <noscript>,
# CSS url(), data-* attributes, and unquoted HTML attributes.
# ---------------------------------------------------------------------------

function Get-LinksFromWebPage {
    param([string]$PageUrl)

    if ($PageUrl -notmatch '^https?://') { $PageUrl = "https://$PageUrl" }

    $response = Invoke-WebRequestWithRetry `
        -Url $PageUrl `
        -MaxRetries $RetryCount `
        -WaitSec $WaitSeconds `
        -Timeout $TimeoutSeconds `
        -DoSecondFetch $SecondFetch `
        -SecondWait $SecondFetchWait

    $html = $response.Content
    Write-Host "  Page content length: $($html.Length) characters"

    # Resolve base URI from the final response URL after redirects.
    # Try PS 5.1 style first (.ResponseUri), then PS 7 style
    # (.RequestMessage.RequestUri), fall back to the original URL.
    $finalUrl = $PageUrl
    try {
        if ($response.BaseResponse.ResponseUri) {
            $finalUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
        }
    }
    catch {
        try {
            if ($response.BaseResponse.RequestMessage.RequestUri) {
                $finalUrl = $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
            }
        }
        catch {
            $finalUrl = $PageUrl
        }
    }
    $baseUri = [uri]$finalUrl

    # Honour <base href="..."> if the page declares one.
    $baseTag = [regex]::Match(
        $html,
        '(?i)<base[^>]+href\s*=\s*["''](?<href>[^"'']+)["'']'
    )
    if ($baseTag.Success) {
        $baseHref = Normalize-Link -Link $baseTag.Groups["href"].Value -BaseUri $baseUri
        if ($baseHref) {
            $baseUri = [uri]$baseHref
            Write-Host "  Using <base href>: $baseHref"
        }
    }

    # Use List[string] so -KeepDuplicates is not silently broken.
    $found = New-Object System.Collections.Generic.List[string]

    # ----- 1. Quoted HTML attributes: href, src, action, data-*, etc. -----
    $attrRegex = '(?i)\b(?:href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*["''](?<url>[^"'']+)["'']'
    foreach ($m in [regex]::Matches($html, $attrRegex)) {
        $val = $m.Groups["url"].Value
        if ($val -match '\s\d+[wx]') {
            # srcset value -- split by comma, take first token of each
            foreach ($entry in $val -split ',') {
                $parts = $entry.Trim() -split '\s+'
                if ($parts.Count -ge 1) { $found.Add($parts[0]) }
            }
        }
        else {
            $found.Add($val)
        }
    }

    # Unquoted HTML attributes (e.g. href=https://example.com)
    $unquotedAttrRegex = '(?i)\b(?:href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster)\s*=\s*(?<url>[^\s"''>]+)'
    foreach ($m in [regex]::Matches($html, $unquotedAttrRegex)) {
        $found.Add($m.Groups["url"].Value)
    }

    # ----- 2. Raw absolute / protocol-relative / bare URLs anywhere -------
    $rawUrlRegex = @'
(?ix)
(?:
    https?://[^\s<>"'\)\]\}]+
  | //[^\s<>"'\)\]\}]+
  | www\.[^\s<>"'\)\]\}]+
  | (?<![@/\w.-])[a-z0-9][a-z0-9.-]+\.[a-z]{2,}(?::\d+)?(?:/[^\s<>"'\)\]\}]*)?
)
'@
    foreach ($m in [regex]::Matches($html, $rawUrlRegex)) {
        $found.Add($m.Value)
    }

    # ----- 3. URLs inside <script> blocks (JSON, JS assignments, etc.) ----
    $scriptRegex = '(?is)<script[^>]*>(?<body>.*?)</script>'
    foreach ($scriptMatch in [regex]::Matches($html, $scriptRegex)) {
        $body = $scriptMatch.Groups["body"].Value

        # Quoted strings that look like URLs
        $jsUrlRegex = '(?:"|''|`)(?<url>(?:https?:)?//[^"''`\s]{5,})(?:"|''|`)'
        foreach ($m in [regex]::Matches($body, $jsUrlRegex)) {
            $raw = Decode-JsUrl $m.Groups["url"].Value
            $found.Add($raw)
        }

        # JSON-style "key": "/path/..." or "key": "https://..."
        $jsonPathRegex = '(?i)"[^"]*"\s*:\s*"(?<url>/[^"]{2,}|https?://[^"]+)"'
        foreach ($m in [regex]::Matches($body, $jsonPathRegex)) {
            $found.Add((Decode-JsUrl $m.Groups["url"].Value))
        }
    }

    # ----- 4. <noscript> blocks (fallback content for no-JS) --------------
    $noscriptRegex = '(?is)<noscript[^>]*>(?<body>.*?)</noscript>'
    foreach ($nsMatch in [regex]::Matches($html, $noscriptRegex)) {
        $nsBody = $nsMatch.Groups["body"].Value
        foreach ($m in [regex]::Matches($nsBody, $attrRegex)) {
            $found.Add($m.Groups["url"].Value)
        }
        foreach ($m in [regex]::Matches($nsBody, $unquotedAttrRegex)) {
            $found.Add($m.Groups["url"].Value)
        }
    }

    # ----- 5. CSS url() references ----------------------------------------
    $cssUrlRegex = '(?i)url\(\s*["'']?(?<url>[^"''\)\s]+)["'']?\s*\)'
    foreach ($m in [regex]::Matches($html, $cssUrlRegex)) {
        $found.Add($m.Groups["url"].Value)
    }

    # Normalize everything and remove failed normalisations
    return @(
        $found |
        ForEach-Object {
            Normalize-Link -Link $_ -BaseUri $baseUri
        } |
        Where-Object { $_ }
    )
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Helper: filter, dedup, blacklist-check, and append links to the output file.
# Returns a stats object with Matched, Blacklisted, Duplicates, Written counts.
function Write-MatchedLinks {
    param(
        [string[]]$Links,
        [string[]]$RegexList,
        [ValidateSet("Any", "All")]
        [string]$SearchMode,
        [string]$OutFile,
        [System.Collections.Generic.HashSet[string]]$WrittenSet,
        [System.Collections.Generic.HashSet[string]]$BlacklistSet
    )

    $stats = [pscustomobject]@{
        Matched     = 0
        Blacklisted = 0
        Duplicates  = 0
        Written     = 0
    }

    # Apply search pattern(s)
    $matched = @(
        $Links | Where-Object {
            Test-LinkMatchesSearch -Link $_ -RegexList $RegexList -Mode $SearchMode
        }
    )

    $stats.Matched = $matched.Count
    if ($matched.Count -eq 0) { return $stats }

    # Remove duplicates within this batch unless told otherwise
    if (-not $KeepDuplicates) {
        $matched = @($matched | Sort-Object -Unique)
    }

    # Skip blacklisted links (only when scope is Output or Both)
    if ((Test-BlacklistAppliesToOutput) -and $BlacklistSet.Count -gt 0) {
        $beforeBl = $matched.Count
        $matched = @(
            $matched | Where-Object {
                -not (Test-IsBlacklisted -Url $_ -BlacklistSet $BlacklistSet)
            }
        )
        $stats.Blacklisted = $beforeBl - $matched.Count
    }

    if ($matched.Count -eq 0) { return $stats }

    # Skip links already written -- only when NoDuplicates is enabled
    if ($NoDuplicates) {
        $beforeDedup = $matched.Count
        $toWriteList = New-Object System.Collections.Generic.List[string]

        if ($KeepDuplicates) {
            foreach ($link in $matched) {
                $key = Get-LinkKey $link

                # Keep duplicates from this page, but still skip links already
                # present in the existing output file or written by previous pages.
                if (-not $WrittenSet.Contains($key)) {
                    $toWriteList.Add($link)
                }
            }
        }
        else {
            $seenThisBatch = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )

            foreach ($link in $matched) {
                $key = Get-LinkKey $link

                if (
                    -not $WrittenSet.Contains($key) -and
                    $seenThisBatch.Add($key)
                ) {
                    $toWriteList.Add($link)
                }
            }
        }

        $toWrite = @($toWriteList)
        $stats.Duplicates = $beforeDedup - $toWrite.Count
    }
    else {
        $toWrite = @($matched)
    }

    if ($toWrite.Count -eq 0) { return $stats }

    # Write and track
    $toWrite | Add-Content -Path $OutFile -Encoding UTF8

    if ($NoDuplicates) {
        foreach ($link in $toWrite) {
            [void]$WrittenSet.Add((Get-LinkKey $link))
        }
    }

    $stats.Written = $toWrite.Count
    return $stats
}

try {
    # Prevent overwriting the source file by mistake
    if ($SourceType -eq "File") {
        $sourceFull = [System.IO.Path]::GetFullPath($Source)
        $outputFull = [System.IO.Path]::GetFullPath($OutputFile)
        if ($sourceFull -ieq $outputFull) {
            throw "Input file and output file are the same. Refusing to overwrite: $Source"
        }
    }

    # Prevent output/log/failed files from being the same as any blacklist file
    if ($BlacklistFile) {
        $outputFull = [System.IO.Path]::GetFullPath($OutputFile)

        if ($LogCsv) {
            $logFull = [System.IO.Path]::GetFullPath($LogCsv)
        }

        if ($FailedUrlFile) {
            $failedFull = [System.IO.Path]::GetFullPath($FailedUrlFile)
        }

        foreach ($blFile in $BlacklistFile) {
            $blacklistFull = [System.IO.Path]::GetFullPath($blFile)

            if ($blacklistFull -ieq $outputFull) {
                throw "Output file and blacklist file are the same. Refusing to use: $blFile"
            }

            if ($LogCsv -and $blacklistFull -ieq $logFull) {
                throw "Log CSV file and blacklist file are the same. Refusing to use: $blFile"
            }

            if ($FailedUrlFile -and $blacklistFull -ieq $failedFull) {
                throw "Failed URL file and blacklist file are the same. Refusing to use: $blFile"
            }
        }
    }

    # Prevent FailedUrlFile collisions
    if ($FailedUrlFile) {
        $failedFull = [System.IO.Path]::GetFullPath($FailedUrlFile)
        $outputFull = [System.IO.Path]::GetFullPath($OutputFile)
        if ($failedFull -ieq $outputFull) {
            throw "Failed URL file and output file are the same: $FailedUrlFile"
        }
        if ($SourceType -eq "File") {
            $sourceFull = [System.IO.Path]::GetFullPath($Source)
            if ($failedFull -ieq $sourceFull) {
                throw "Failed URL file and source file are the same: $FailedUrlFile"
            }
        }
    }

    # Prevent LogCsv collisions
    if ($LogCsv) {
        $logFull    = [System.IO.Path]::GetFullPath($LogCsv)
        $outputFull = [System.IO.Path]::GetFullPath($OutputFile)
        if ($logFull -ieq $outputFull) {
            throw "Log CSV file and output file are the same: $LogCsv"
        }
        if ($SourceType -eq "File") {
            $sourceFull = [System.IO.Path]::GetFullPath($Source)
            if ($logFull -ieq $sourceFull) {
                throw "Log CSV file and source file are the same: $LogCsv"
            }
        }
    }

    # Prevent LogCsv == FailedUrlFile
    if ($LogCsv -and $FailedUrlFile) {
        $logFull    = [System.IO.Path]::GetFullPath($LogCsv)
        $failedFull = [System.IO.Path]::GetFullPath($FailedUrlFile)
        if ($logFull -ieq $failedFull) {
            throw "Log CSV file and failed URL file are the same: $LogCsv"
        }
    }


    # Ensure output folder exists
    $folder = Split-Path -Parent $OutputFile
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    if ($Mode -eq "New") {
        Set-Content -Path $OutputFile -Value @() -Encoding UTF8
        Write-Host "Output file created/overwritten: $OutputFile"
    }
    elseif (-not (Test-Path -LiteralPath $OutputFile)) {
        New-Item -ItemType File -Path $OutputFile -Force | Out-Null
        Write-Host "Output file created: $OutputFile"
    }

    # Set up FailedUrlFile
    if ($FailedUrlFile) {
        $failedFolder = Split-Path -Parent $FailedUrlFile
        if ($failedFolder -and -not (Test-Path -LiteralPath $failedFolder)) {
            New-Item -ItemType Directory -Path $failedFolder -Force | Out-Null
        }

        $failedHeader = "SourceUrl`tError"

        if ($FailedUrlMode -eq "New") {
            Set-Content -Path $FailedUrlFile -Value $failedHeader -Encoding UTF8
            Write-Host "Failed URL file created/overwritten: $FailedUrlFile"
        }
        elseif (-not (Test-Path -LiteralPath $FailedUrlFile)) {
            Set-Content -Path $FailedUrlFile -Value $failedHeader -Encoding UTF8
            Write-Host "Failed URL file created: $FailedUrlFile"
        }
        else {
            $failedItem = Get-Item -LiteralPath $FailedUrlFile -ErrorAction Stop
            if ($failedItem.Length -eq 0) {
                Set-Content -Path $FailedUrlFile -Value $failedHeader -Encoding UTF8
                Write-Host "Failed URL file was empty; header added: $FailedUrlFile"
            }
        }
    }

    # Set up LogCsv
    if ($LogCsv) {
        $logFolder = Split-Path -Parent $LogCsv
        if ($logFolder -and -not (Test-Path -LiteralPath $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        }

        $csvHeader = "Timestamp,SourceUrl,Status,Extracted,Matched,Blacklisted,Duplicates,Written,Error"

        if ($LogMode -eq "New") {
            Set-Content -Path $LogCsv -Value $csvHeader -Encoding UTF8
            Write-Host "Log CSV file created/overwritten: $LogCsv"
        }
        elseif (-not (Test-Path -LiteralPath $LogCsv)) {
            Set-Content -Path $LogCsv -Value $csvHeader -Encoding UTF8
            Write-Host "Log CSV file created: $LogCsv"
        }
        else {
            $logItem = Get-Item -LiteralPath $LogCsv -ErrorAction Stop
            if ($logItem.Length -eq 0) {
                Set-Content -Path $LogCsv -Value $csvHeader -Encoding UTF8
                Write-Host "Log CSV file was empty; header added: $LogCsv"
            }
        }
    }

    # Build a set of everything already in the output file (for -NoDuplicates).
    $writtenSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ($NoDuplicates -and (Test-Path -LiteralPath $OutputFile)) {
        $existingRaw = Get-Content -LiteralPath $OutputFile -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($existingRaw) {
            foreach ($line in $existingRaw) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    [void]$writtenSet.Add((Get-LinkKey $line))
                }
            }
            Write-Host "Loaded $($writtenSet.Count) existing link(s) from output file."
        }
    }

    # Load blacklist files into a single set
    $blacklistSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ($BlacklistFile) {
        foreach ($blFile in $BlacklistFile) {
            if (-not (Test-Path -LiteralPath $blFile)) {
                Write-Host "WARNING: Blacklist file not found, skipping: $blFile"
                continue
            }

            $blRaw = Get-Content -LiteralPath $blFile -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($blRaw) {
                $countBefore = $blacklistSet.Count
                foreach ($blLine in $blRaw) {
                    if (-not [string]::IsNullOrWhiteSpace($blLine) -and
                        -not $blLine.Trim().StartsWith("#")) {
                        $normalized = Normalize-Link -Link $blLine
                        if ($normalized) {
                            [void]$blacklistSet.Add((Get-LinkKey $normalized))
                        }
                    }
                }
                $added = $blacklistSet.Count - $countBefore
                Write-Host "Loaded $added blacklisted URL(s) from: $blFile"
            }
        }

        if ($blacklistSet.Count -gt 0) {
            Write-Host "Total blacklisted URLs: $($blacklistSet.Count)"
        }
    }

    $effectiveSearchPatterns = Get-EffectiveSearchPatterns
    $searchRegexList = @(
        $effectiveSearchPatterns | ForEach-Object {
            Convert-WildcardToRegex -Pattern $_
        }
    )

    Write-Host "Search pattern(s): $($effectiveSearchPatterns -join ', ')"
    Write-Host "Search mode: $SearchMode"
    $totalWritten        = 0
    $totalExtracted      = 0
    $totalMatched        = 0
    $totalBlacklistSrc   = 0
    $totalBlacklistOut   = 0
    $totalDupes          = 0
    $totalFailed         = 0

    # Helper: write one row to the CSV log
    function Write-LogCsvRow {
        param(
            [string]$Url,
            [string]$Status,
            [int]$Extracted,
            [int]$Matched,
            [int]$Blacklisted,
            [int]$Duplicates,
            [int]$Written,
            [string]$ErrorMsg
        )

        if (-not $LogCsv) { return }

        $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        # Escape fields that might contain commas or quotes
        $safeUrl   = '"' + $Url.Replace('"', '""') + '"'
        $safeError = '"' + $ErrorMsg.Replace('"', '""') + '"'

        $row = "$ts,$safeUrl,$Status,$Extracted,$Matched,$Blacklisted,$Duplicates,$Written,$safeError"
        Add-Content -Path $LogCsv -Value $row -Encoding UTF8
    }

    if ($SourceType -eq "Url") {
        # Single URL mode -- fetch, filter, write
        $sourceUrl = Normalize-Link -Link $Source

        if ((Test-BlacklistAppliesToInput) -and (Test-IsBlacklisted -Url $sourceUrl -BlacklistSet $blacklistSet)) {
            Write-Host "Source URL is blacklisted. Skipping: $sourceUrl"
            $totalBlacklistSrc++

            Write-LogCsvRow -Url $sourceUrl -Status "BLACKLISTED_SOURCE" `
                -Extracted 0 -Matched 0 -Blacklisted 1 -Duplicates 0 `
                -Written 0 -ErrorMsg ""
        }
        else {
            Write-Host "Fetching page: $Source"
            try {
                $links = @(Get-LinksFromWebPage -PageUrl $Source)
                $totalExtracted = $links.Count
                Write-Host "  Extracted $($links.Count) link(s)."

                $stats = Write-MatchedLinks -Links $links -RegexList $searchRegexList `
                            -SearchMode $SearchMode `
                            -OutFile $OutputFile -WrittenSet $writtenSet `
                            -BlacklistSet $blacklistSet
                $totalMatched        += $stats.Matched
                $totalBlacklistOut   += $stats.Blacklisted
                $totalDupes          += $stats.Duplicates
                $totalWritten        += $stats.Written

                Write-Host "  Matched: $($stats.Matched) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written)"

                Write-LogCsvRow -Url $Source -Status "OK" `
                    -Extracted $links.Count -Matched $stats.Matched `
                    -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                    -Written $stats.Written -ErrorMsg ""
            }
            catch {
                $totalFailed++
                $errorMessage = $_.Exception.Message
                Write-Host "  FAILED: $errorMessage"

                Write-LogCsvRow -Url $Source -Status "FAILED" `
                    -Extracted 0 -Matched 0 -Blacklisted 0 -Duplicates 0 `
                    -Written 0 -ErrorMsg $errorMessage

                if ($FailedUrlFile) {
                    $failedLine = "$Source`t$errorMessage"
                    Add-Content -Path $FailedUrlFile -Value $failedLine -Encoding UTF8
                }
            }
        }
    }
    elseif ($SourceType -eq "File") {
        # Multi-URL mode -- read file, fetch each page, filter+write per page
        Write-Host "Reading URLs from file: $Source"

        if (-not (Test-Path -LiteralPath $Source)) {
            throw "Input file does not exist: $Source"
        }

        $raw = Get-Content -LiteralPath $Source -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            throw "Input file is empty: $Source"
        }

        $lines = $raw -split "\r\n|\n|\r"

        # Normalise and deduplicate source URLs before fetching
        $urlsRaw = @(
            $lines |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_) -and
                -not $_.Trim().StartsWith("#")
            } |
            ForEach-Object { Normalize-Link -Link $_ } |
            Where-Object { $_ }
        )

        Write-Host "Valid source URLs before deduplication: $($urlsRaw.Count)"

        $seenSourceUrls = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $urls = @(
            foreach ($u in $urlsRaw) {
                $key = Get-LinkKey $u
                if ($seenSourceUrls.Add($key)) {
                    $u
                }
            }
        )

        $dupeSourceCount = $urlsRaw.Count - $urls.Count
        if ($dupeSourceCount -gt 0) {
            Write-Host "Removed $dupeSourceCount duplicate source URL(s)."
        }

        # Remove blacklisted source URLs before fetching
        if ((Test-BlacklistAppliesToInput) -and $blacklistSet.Count -gt 0) {
            $beforeInputBlacklist = $urls.Count

            $blacklistedSourceUrls = @(
                $urls | Where-Object {
                    Test-IsBlacklisted -Url $_ -BlacklistSet $blacklistSet
                }
            )

            $urls = @(
                $urls | Where-Object {
                    -not (Test-IsBlacklisted -Url $_ -BlacklistSet $blacklistSet)
                }
            )

            $blacklistedInputCount = $beforeInputBlacklist - $urls.Count
            if ($blacklistedInputCount -gt 0) {
                Write-Host "Removed $blacklistedInputCount blacklisted source URL(s)."
                $totalBlacklistSrc += $blacklistedInputCount

                foreach ($blacklistedUrl in $blacklistedSourceUrls) {
                    Write-LogCsvRow -Url $blacklistedUrl -Status "BLACKLISTED_SOURCE" `
                        -Extracted 0 -Matched 0 -Blacklisted 1 -Duplicates 0 `
                        -Written 0 -ErrorMsg ""
                }
            }
        }

        if ($urls.Count -eq 0) {
            if ($urlsRaw.Count -gt 0 -and (Test-BlacklistAppliesToInput) -and $totalBlacklistSrc -gt 0) {
                Write-Host "No URLs left to fetch after blacklist filtering."
                Write-Host ""
            }
            else {
                throw "No valid URLs found in input file."
            }
        }
        else {
            Write-Host "Fetching $($urls.Count) unique URL(s) from input file."
            Write-Host ""
        }

        if ($urls.Count -gt 0) {
            $index = 0
            foreach ($url in $urls) {
                $index++
                Write-Host "[$index / $($urls.Count)] Fetching: $url"

                try {
                    $links = @(Get-LinksFromWebPage -PageUrl $url)
                    $totalExtracted += $links.Count
                    Write-Host "  Extracted $($links.Count) link(s)."

                    $stats = Write-MatchedLinks -Links $links -RegexList $searchRegexList `
                                -SearchMode $SearchMode `
                                -OutFile $OutputFile -WrittenSet $writtenSet `
                                -BlacklistSet $blacklistSet
                    $totalMatched        += $stats.Matched
                    $totalBlacklistOut   += $stats.Blacklisted
                    $totalDupes          += $stats.Duplicates
                    $totalWritten        += $stats.Written

                    Write-Host "  Matched: $($stats.Matched) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written)"

                    Write-LogCsvRow -Url $url -Status "OK" `
                        -Extracted $links.Count -Matched $stats.Matched `
                        -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                        -Written $stats.Written -ErrorMsg ""
                }
                catch {
                    $totalFailed++
                    $errorMessage = $_.Exception.Message

                    Write-Host "  FAILED: $errorMessage"
                    Write-Host "  Skipping this URL and continuing."

                    Write-LogCsvRow -Url $url -Status "FAILED" `
                        -Extracted 0 -Matched 0 -Blacklisted 0 -Duplicates 0 `
                        -Written 0 -ErrorMsg $errorMessage

                    if ($FailedUrlFile) {
                        $failedLine = "$url`t$errorMessage"
                        Add-Content -Path $FailedUrlFile -Value $failedLine -Encoding UTF8
                    }
                }

                # Pause between URLs to be polite to servers
                if ($index -lt $urls.Count -and $DelaySeconds -gt 0) {
                    Write-Host "  Waiting $DelaySeconds second(s) before next URL ..."
                    Start-Sleep -Seconds $DelaySeconds
                }

                Write-Host ""
            }
        }
    }
    else {
        throw "Unsupported SourceType: $SourceType"
    }

    Write-Host "--- Done ---"
    Write-Host "Total links extracted:       $totalExtracted"
    Write-Host "Total matched pattern(s):    $totalMatched"
    Write-Host "Total blacklisted (source):  $totalBlacklistSrc"
    Write-Host "Total blacklisted (output):  $totalBlacklistOut"
    Write-Host "Total duplicates:            $totalDupes"
    Write-Host "Total written to file:       $totalWritten"
    Write-Host "Total failed URLs:           $totalFailed"
    Write-Host "Output file: $OutputFile"
    if ($LogCsv) {
        Write-Host "Log CSV: $LogCsv"
        Write-Host "Log CSV mode: $LogMode"
    }
    if ($FailedUrlFile) {
        Write-Host "Failed URL file: $FailedUrlFile"
        Write-Host "Failed URL file mode: $FailedUrlMode"
    }

    # In single URL mode, exit with error code if the only URL failed
    if ($SourceType -eq "Url" -and $totalFailed -gt 0) {
        exit 1
    }
}
catch {
    Write-Error "Failed: $($_.Exception.Message)"
    exit 1
}