#requires -Version 5.1

# Find-WebLinks.ps1 - 1.5.0
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

    [Parameter(Mandatory = $false)]
    [string]$ExcludePattern,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePatterns,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Any", "All")]
    [string]$ExcludeMode = "Any",

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateSet("Append", "New")]
    [string]$Mode = "Append",

    [Parameter(Mandatory = $false, Position = 4)]
    [ValidateSet("Url", "File")]
    [string]$SourceType = "Url",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$RetryCount = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$WaitSeconds = 30,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$TimeoutSeconds = 120,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$DelaySeconds = 5,

    [Parameter(Mandatory = $false)]
    [bool]$SecondFetch = $true,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
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
    [ValidateRange(1, 2147483647)]
    [int]$ThrottleLimit = 1,

    [Parameter(Mandatory = $false)]
    [switch]$Resume,

    [Parameter(Mandatory = $false)]
    [switch]$DeduplicateFiles,

    [Parameter(Mandatory = $false)]
    [switch]$KeepFragments,

    [Parameter(Mandatory = $false)]
    [string]$Proxy,

    [Parameter(Mandatory = $false)]
    [bool]$SortOutput = $false,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Run", "Deduplicate", "Sort", "Maintain")]
    [string]$Command = "Run",

    [Parameter(Mandatory = $false)]
    [Alias("MaintenanceFiles")]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Ascending", "Descending")]
    [string]$SortDirection = "Ascending",

    [Parameter(Mandatory = $false)]
    [ValidateSet("None", "Start", "End", "Both")]
    [string]$DeduplicateWhen = "None",

    [Parameter(Mandatory = $false)]
    [ValidateSet("None", "Start", "End", "Both")]
    [string]$SortWhen = "None",

    [Parameter(Mandatory = $false)]
    [string]$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",

    [Parameter(Mandatory = $false)]
    [string]$ProgressFile,

    [Parameter(Mandatory = $false)]
    [string]$LogCsv,

    [Parameter(Mandatory = $false)]
    [string]$FailedUrlFile,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Append", "New")]
    [string]$LogMode = "Append",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Append", "New")]
    [string]$FailedUrlMode = "Append",

    # Advanced operational limits. Defaults preserve existing behaviour.
    # Set -MaintenanceLargeFileLimitMB 0, or use -IgnoreMaintenanceLargeFileLimit,
    # to allow dedup/sort on files larger than the default safety limit.
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaintenanceLargeFileLimitMB = 1024,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreMaintenanceLargeFileLimit,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxPageContentMB = 50,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$RegexTimeoutSeconds = 10,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxUrlLength = 8192,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$MaxRedirects = 10,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxRetryAfterSeconds = 300,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$FileWriteRetryCount = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$FileWriteRetryDelayMinMs = 50,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$FileWriteRetryDelayMaxMs = 300,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$FileMoveRetryCount = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$FileMoveRetryDelayMs = 300,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$ConnectionLimit = 100,

    # Keeps typo guardrails in place while still allowing intentional extreme values.
    # Example: -RetryCount 100000 requires -AllowExtremeOperationalValues.
    [Parameter(Mandatory = $false)]
    [switch]$AllowExtremeOperationalValues,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [double]$HighFailureRatePercent = 50
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

if ($FileWriteRetryDelayMinMs -gt $FileWriteRetryDelayMaxMs) {
    throw "-FileWriteRetryDelayMinMs cannot be greater than -FileWriteRetryDelayMaxMs."
}

function Assert-OperationalGuardrail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [long]$Value,

        [Parameter(Mandatory = $true)]
        [long]$SafeMaximum
    )

    if ($AllowExtremeOperationalValues) { return }

    if ($Value -gt $SafeMaximum) {
        throw "-$Name $Value exceeds the normal safety guardrail of $SafeMaximum. This is usually a typo. If you really want this value, rerun with -AllowExtremeOperationalValues."
    }
}

# These are typo guardrails, not hard limits. Use -AllowExtremeOperationalValues
# when intentionally running unusual values for very large jobs or controlled tests.
Assert-OperationalGuardrail -Name "RetryCount" -Value $RetryCount -SafeMaximum 100
Assert-OperationalGuardrail -Name "WaitSeconds" -Value $WaitSeconds -SafeMaximum 86400
Assert-OperationalGuardrail -Name "TimeoutSeconds" -Value $TimeoutSeconds -SafeMaximum 86400
Assert-OperationalGuardrail -Name "DelaySeconds" -Value $DelaySeconds -SafeMaximum 86400
Assert-OperationalGuardrail -Name "SecondFetchWait" -Value $SecondFetchWait -SafeMaximum 86400
Assert-OperationalGuardrail -Name "ThrottleLimit" -Value $ThrottleLimit -SafeMaximum 64
Assert-OperationalGuardrail -Name "MaxPageContentMB" -Value $MaxPageContentMB -SafeMaximum 1024
Assert-OperationalGuardrail -Name "RegexTimeoutSeconds" -Value $RegexTimeoutSeconds -SafeMaximum 3600
Assert-OperationalGuardrail -Name "MaxUrlLength" -Value $MaxUrlLength -SafeMaximum 1048576
Assert-OperationalGuardrail -Name "MaxRedirects" -Value $MaxRedirects -SafeMaximum 100
Assert-OperationalGuardrail -Name "MaxRetryAfterSeconds" -Value $MaxRetryAfterSeconds -SafeMaximum 86400
Assert-OperationalGuardrail -Name "FileWriteRetryCount" -Value $FileWriteRetryCount -SafeMaximum 100
Assert-OperationalGuardrail -Name "FileWriteRetryDelayMinMs" -Value $FileWriteRetryDelayMinMs -SafeMaximum 86400000
Assert-OperationalGuardrail -Name "FileWriteRetryDelayMaxMs" -Value $FileWriteRetryDelayMaxMs -SafeMaximum 86400000
Assert-OperationalGuardrail -Name "FileMoveRetryCount" -Value $FileMoveRetryCount -SafeMaximum 100
Assert-OperationalGuardrail -Name "FileMoveRetryDelayMs" -Value $FileMoveRetryDelayMs -SafeMaximum 86400000
Assert-OperationalGuardrail -Name "ConnectionLimit" -Value $ConnectionLimit -SafeMaximum 10000

if ($AllowExtremeOperationalValues) {
    Write-Warning "Extreme operational value guardrails are disabled for this run. Make sure these values are intentional."
}

[System.Net.ServicePointManager]::DefaultConnectionLimit = $ConnectionLimit
# Enforce TLS 1.2+ for modern HTTPS sites (PS 5.1 defaults to TLS 1.0 on older systems)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Centralised operational limits. Defaults preserve previous hardcoded values.
# Any 0 MB size limit means "no limit" for that guard.
if ($IgnoreMaintenanceLargeFileLimit -or $MaintenanceLargeFileLimitMB -eq 0) {
    [int64]$Script:MaintenanceLargeFileLimitBytes = 0
}
else {
    [int64]$Script:MaintenanceLargeFileLimitBytes = [int64]$MaintenanceLargeFileLimitMB * 1MB
}

if ($MaxPageContentMB -eq 0) {
    [int64]$Script:MaxPageContentBytes = 0
}
else {
    [int64]$Script:MaxPageContentBytes = [int64]$MaxPageContentMB * 1MB
}

[int]$Script:MaxUrlLength = $MaxUrlLength
[int]$Script:MaxRedirects = $MaxRedirects
[int]$Script:MaxRetryAfterSeconds = $MaxRetryAfterSeconds
[int]$Script:MaxPageContentMB = $MaxPageContentMB
[int]$Script:FileWriteRetryCount = $FileWriteRetryCount
[int]$Script:FileWriteRetryDelayMinMs = $FileWriteRetryDelayMinMs
[int]$Script:FileWriteRetryDelayMaxMs = $FileWriteRetryDelayMaxMs
[int]$Script:FileMoveRetryCount = $FileMoveRetryCount
[int]$Script:FileMoveRetryDelayMs = $FileMoveRetryDelayMs
$Script:RegexTimeout = if ($RegexTimeoutSeconds -eq 0) {
    [System.Text.RegularExpressions.Regex]::InfiniteMatchTimeout
}
else {
    [TimeSpan]::FromSeconds($RegexTimeoutSeconds)
}

function Show-Usage {
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  Run / scrape mode:"
    Write-Host "  .\Find-WebLinks.ps1 <Source> <SearchPattern> <OutputFile> [Mode] [SourceType] [options]"
    Write-Host "  .\Find-WebLinks.ps1 <Source> -SearchPatterns <patterns> -OutputFile <OutputFile> [options]"
    Write-Host ""
    Write-Host "  Maintenance-only mode, no downloading:"
    Write-Host "  .\Find-WebLinks.ps1 -Command Deduplicate -Files <f1>,<f2>"
    Write-Host "  .\Find-WebLinks.ps1 -Command Sort -Files <f1>,<f2> [-SortDirection Ascending|Descending]"
    Write-Host "  .\Find-WebLinks.ps1 -Command Maintain -Files <f1>,<f2> -DeduplicateWhen <Start|End|Both> -SortWhen <Start|End|Both>"
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
    Write-Host "  -ExcludePattern <pattern>  Main wildcard pattern to exclude from matched links."
    Write-Host "  -ExcludePatterns <p1>,<p2> One or more wildcard patterns to exclude from matched links."
    Write-Host "  -ExcludeMode <Any|All>     Any = exclude if any exclude pattern hits (default). All = exclude only if every exclude pattern hits."
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
    Write-Host "  -Resume                   Resume a previous File-mode run using the progress file"
    Write-Host "  -ProgressFile <f>         Progress file used by resume mode. Default: <OutputFile>.progress"
    Write-Host "  -ThrottleLimit <n>        Process n URLs in parallel (default: 1 = sequential). Requires PS 7+"
    Write-Host "  -DeduplicateFiles         Legacy: deduplicate source, output, and blacklist files before starting"
    Write-Host "  -KeepFragments            Preserve URL fragments (#...) for deduplication (useful for SPAs)"
    Write-Host "  -UserAgent <string>       Custom User-Agent header (default: Chrome 131)"
    Write-Host "  -Proxy <url>              HTTP proxy URL (e.g. http://proxy:8080)"
    Write-Host "  -SortOutput <bool>        Legacy: sort the output file alphabetically after the run (default: false)"
    Write-Host "  -DeduplicateWhen <None|Start|End|Both>  Deduplicate involved files before, after, or both (default: None)"
    Write-Host "  -SortWhen <None|Start|End|Both>         Sort involved files before, after, or both (default: None)"
    Write-Host "  -SortDirection <Ascending|Descending>   Sort direction for -SortWhen or -Command Sort (default: Ascending)"
    Write-Host ""
    Write-Host "Advanced limit overrides:"
    Write-Host "  -MaintenanceLargeFileLimitMB <n>        Max MB for in-memory dedup/sort (default: 1024, 0 = no limit)"
    Write-Host "  -IgnoreMaintenanceLargeFileLimit        Allow dedup/sort above the maintenance size limit"
    Write-Host "  -MaxPageContentMB <n>                   Max page body size to parse (default: 50, 0 = no limit)"
    Write-Host "  -RegexTimeoutSeconds <n>                Regex match timeout (default: 10, 0 = no timeout)"
    Write-Host "  -MaxUrlLength <n>                       Max URL/key length before truncation (default: 8192, 0 = no limit)"
    Write-Host "  -MaxRedirects <n>                       Max HTTP/meta-refresh redirects (default: 10)"
    Write-Host "  -MaxRetryAfterSeconds <n>               Max server Retry-After wait honoured (default: 300, 0 = ignore)"
    Write-Host "  -ConnectionLimit <n>                    .NET HTTP connection limit (default: 100)"
    Write-Host "  -FileWriteRetryCount <n>                Append retry attempts for output/log/progress files (default: 5)"
    Write-Host "  -FileWriteRetryDelayMinMs <n>           Min delay between append retries (default: 50)"
    Write-Host "  -FileWriteRetryDelayMaxMs <n>           Max delay between append retries (default: 300)"
    Write-Host "  -FileMoveRetryCount <n>                 Replace retry attempts after dedup/sort temp file write (default: 5)"
    Write-Host "  -FileMoveRetryDelayMs <n>               Delay between dedup/sort replace retries (default: 300)"
    Write-Host "  -HighFailureRatePercent <n>             Warn when File-mode failures reach this percent (default: 50, 0 = disable)"
    Write-Host "  -AllowExtremeOperationalValues          Allow values above typo guardrails for advanced parameters"
    Write-Host ""
    Write-Host "Maintenance commands, no downloading:"
    Write-Host "  -Command Deduplicate -Files <f1>,<f2>   Deduplicate one or more files and exit"
    Write-Host "  -Command Sort -Files <f1>,<f2>          Sort one or more files and exit"
    Write-Host "  -Command Maintain -Files <f1>,<f2>      Run requested maintenance on one or more files and exit"
    Write-Host "                                      In standalone mode Start/End/Both collapse to one pass"
    Write-Host ""
    Write-Host "Maintenance examples:"
    Write-Host "  .\Find-WebLinks.ps1 -Command Deduplicate -Files .\a.txt,.\b.txt"
    Write-Host "  .\Find-WebLinks.ps1 -Command Sort -Files .\a.txt,.\b.txt -SortDirection Descending"
    Write-Host "  .\Find-WebLinks.ps1 -Command Deduplicate -Files .\huge.txt -MaintenanceLargeFileLimitMB 0"
    Write-Host "  .\Find-WebLinks.ps1 -Command Maintain -Files .\a.txt,.\b.txt -DeduplicateWhen Start -SortWhen End"
    Write-Host "  .\Find-WebLinks.ps1 .\urls.txt `"*zip*`" .\matches.txt Append File -DeduplicateWhen Start -SortWhen End"
    Write-Host ""
    Write-Host "Resume behaviour:"
    Write-Host "  In File mode, the script writes each completed source URL to a progress file."
    Write-Host "  If interrupted, rerun with -Resume to skip already processed source URLs."
    Write-Host "  Failed URLs are also marked as processed and written to -FailedUrlFile if supplied."
    Write-Host "  The resume signature detects if search/exclude/output settings have changed."
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
    Write-Host "Examples -- include and exclude wildcard patterns:"
    Write-Host ""
    Write-Host "  Save links containing download OR game, but exclude demo and trailer links:"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" -SearchPatterns `"*download*`",`"*game*`" -ExcludePatterns `"*demo*`",`"*trailer*`" -OutputFile `"matched.txt`" Append File"
    Write-Host ""
    Write-Host "  Save links containing BOTH amiga AND lha, but exclude links containing beta:"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" -SearchPatterns `"*amiga*`",`"*lha*`" -SearchMode All -ExcludePattern `"*beta*`" -OutputFile `"matched.txt`" Append File"
    Write-Host ""
    Write-Host "  Exclude only when BOTH unwanted words are present in the same link:"
    Write-Host "  .\Find-WebLinks.ps1 `"urls.txt`" `"*download*`" `"matched.txt`" Append File -ExcludePatterns `"*demo*`",`"*trial*`" -ExcludeMode All"
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

if ($Command -eq "Run" -and (
    [string]::IsNullOrWhiteSpace($Source) -or
    (
        [string]::IsNullOrWhiteSpace($SearchPattern) -and
        (
            -not $SearchPatterns -or
            @($SearchPatterns | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0
        )
    ) -or
    [string]::IsNullOrWhiteSpace($OutputFile)
)) {
    Show-Usage
    exit 0
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-SafeAbsolutePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $unresolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [System.IO.Path]::GetFullPath($unresolved)
}

function Dispose-BaseResponseSafe {
    param([AllowNull()][object]$Response)

    if ($null -eq $Response) { return }

    try {
        if ($Response -is [System.IDisposable]) {
            $Response.Dispose()
        }

        $brProp = $Response.PSObject.Properties['BaseResponse']
        if ($null -ne $brProp -and $null -ne $brProp.Value) {
            if (
                $brProp.Value -is [System.IDisposable] -and
                -not [object]::ReferenceEquals($brProp.Value, $Response)
            ) {
                $brProp.Value.Dispose()
            }
        }
    }
    catch {
        # Never allow cleanup/disposal to mask the real network error.
    }
}

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

function Get-EffectiveExcludePatterns {
    $patterns = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($ExcludePattern)) {
        [void]$patterns.Add($ExcludePattern.Trim())
    }

    if ($ExcludePatterns) {
        foreach ($pattern in $ExcludePatterns) {
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

function Test-LinkMatchesExclude {
    param(
        [string]$Link,
        [string[]]$RegexList,
        [string]$Mode
    )

    if ($null -eq $RegexList -or $RegexList.Count -eq 0) { return $false }
    return (Test-LinkMatchesSearch -Link $Link -RegexList $RegexList -Mode $Mode)
}

# Normalise a link for "same enough" duplicate comparison.
# Strips fragment (#...) unless -KeepFragments is set, protocol, trailing slash, and lowercases.
function Get-LinkKey {
    param([string]$Link)

    if ([string]::IsNullOrWhiteSpace($Link)) { return "" }

    # Guard against absurdly long strings that would spike CPU in URI parsing
    if ($Script:MaxUrlLength -gt 0 -and $Link.Length -gt $Script:MaxUrlLength) {
        $trimmed = $Link.Substring(0, $Script:MaxUrlLength).Trim()

        if (-not $KeepFragments) {
            $hashIndex = $trimmed.IndexOf("#")
            if ($hashIndex -ge 0) {
                $trimmed = $trimmed.Substring(0, $hashIndex)
            }
        }

        $result = $trimmed.TrimEnd('/').ToLowerInvariant()
        $result = $result -replace '^https?://', '//'
        return $result
    }

    try {
        $uri = [uri]$Link
        $builder = [System.UriBuilder]::new($uri)
        if (-not $KeepFragments) {
            $builder.Fragment = ""
        }
        $result = $builder.Uri.AbsoluteUri.TrimEnd('/').ToLowerInvariant()
        # Strip protocol so http:// and https:// produce the same key
        $result = $result -replace '^https?://', '//'
        return $result
    }
    catch {
        $trimmed = $Link.Trim()

        if (-not $KeepFragments) {
            $hashIndex = $trimmed.IndexOf("#")
            if ($hashIndex -ge 0) {
                $trimmed = $trimmed.Substring(0, $hashIndex)
            }
        }

        $result = $trimmed.TrimEnd('/').ToLowerInvariant()
        $result = $result -replace '^https?://', '//'
        return $result
    }
}

function Get-LinkWriteValue {
    param([string]$Link)

    if ([string]::IsNullOrWhiteSpace($Link)) { return "" }

    $trimmed = $Link.Trim()

    if ($KeepFragments) {
        return $trimmed
    }

    try {
        $uri = [uri]$trimmed
        if ($uri.IsAbsoluteUri) {
            $builder = [System.UriBuilder]::new($uri)
            $builder.Fragment = ""
            return $builder.Uri.ToString()
        }
    }
    catch {
        # Fall back to simple string stripping below
    }

    $hashIndex = $trimmed.IndexOf("#")
    if ($hashIndex -ge 0) {
        return $trimmed.Substring(0, $hashIndex)
    }

    return $trimmed
}

function Get-Sha256Text {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-RunSignature {
    param(
        [string]$Source,
        [string]$SourceType,
        [string]$OutputFile,
        [string[]]$SearchPatterns,
        [string]$SearchMode,
        [string[]]$ExcludePatterns,
        [string]$ExcludeMode,
        [string]$BlacklistScope,
        [string[]]$BlacklistPaths,
        [bool]$SecondFetch,
        [bool]$KeepDuplicates,
        [bool]$NoDuplicates,
        [bool]$KeepFragments
    )

    $sourceSig = $Source
    $outputSig = $OutputFile

    if ($SourceType -eq "File") {
        $sourceSig = Get-SafeAbsolutePath $Source
    }
    $outputSig = Get-SafeAbsolutePath $OutputFile

    $delim = [char]0x1F  # Unit separator -- cannot appear in user patterns
    $signatureText = @(
        "SourceType=$SourceType"
        "Source=$sourceSig"
        "OutputFile=$outputSig"
        "SearchPatterns=$($SearchPatterns -join $delim)"
        "SearchMode=$SearchMode"
        "ExcludePatterns=$($ExcludePatterns -join $delim)"
        "ExcludeMode=$ExcludeMode"
        "BlacklistScope=$BlacklistScope"
        "BlacklistPaths=$($BlacklistPaths -join $delim)"
        "SecondFetch=$SecondFetch"
        "KeepDuplicates=$KeepDuplicates"
        "NoDuplicates=$NoDuplicates"
        "KeepFragments=$KeepFragments"
    ) -join "`n"

    return Get-Sha256Text $signatureText
}

function Initialize-ProgressFile {
    param(
        [string]$Path,
        [string]$Signature,
        [switch]$Resume
    )

    $completed = [System.Collections.Concurrent.ConcurrentDictionary[string, byte]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ((Test-Path -LiteralPath $Path) -and $Resume) {
        # Handle 0-byte progress file from a crash during creation
        $fileInfo = Get-Item -LiteralPath $Path
        if ($fileInfo.Length -eq 0) {
            Write-Host "Progress file is empty (likely from a crash). Removing and starting fresh."
            Remove-Item -LiteralPath $Path -Force
        }
        else {
        $safeProgressPath = Get-SafeAbsolutePath $Path
        $lineEnum = [System.IO.File]::ReadLines($safeProgressPath, [System.Text.Encoding]::UTF8).GetEnumerator()

        $signatureLine = $null
        try {
            while ($lineEnum.MoveNext()) {
                if ($lineEnum.Current -match '^# Signature:') {
                    $signatureLine = $lineEnum.Current
                    break
                }
            }

            if (-not $signatureLine) {
                throw "Progress file exists but has no signature. Delete it or use a different -ProgressFile."
            }

            $existingSignature = ($signatureLine -replace '^# Signature:\s*', '').Trim()

            if ($existingSignature -ne $Signature) {
                throw "Progress file belongs to a different run configuration. The search, exclude, blacklist, source, or output settings changed. Delete the progress file to start a fresh run, or rerun with the original command."
            }

            # Continue reading the rest of the file to populate the completed set
            while ($lineEnum.MoveNext()) {
                $line = $lineEnum.Current
                if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) { continue }
                [void]$completed.TryAdd($line.Trim(), [byte]0)
            }
        }
        finally {
            $lineEnum.Dispose()
        }

        Write-Host "Resume enabled. Loaded $($completed.Count) completed source URL(s) from progress file."
        }  # end else (non-empty progress file)
    }
    elseif ((Test-Path -LiteralPath $Path) -and -not $Resume) {
        throw "Progress file already exists: $Path. This usually means a previous run was interrupted. Use -Resume to continue, delete the progress file to start fresh, or specify a different -ProgressFile."
    }
    else {
        $folder = Split-Path -Parent $Path
        if ($folder -and -not (Test-Path -LiteralPath $folder)) {
            [void](New-Item -ItemType Directory -Path $folder -Force)
        }

        Set-Content -LiteralPath $Path -Value @(
            "# Find-WebLinks progress file"
            "# Signature: $Signature"
            "# One completed source URL key per line"
        ) -Encoding UTF8

        if ($Resume) {
            Write-Host "Resume requested, but no progress file exists yet. Starting a new resumable run."
        }
        Write-Host "Progress file created: $Path"
    }

    return $completed
}

function Add-CompletedProgress {
    param(
        [string]$Path,
        [string]$Url,
        $CompletedSet
    )

    $key = Get-LinkKey $Url

    if ([string]::IsNullOrWhiteSpace($key)) { return }

    if ($CompletedSet.TryAdd($key, [byte]0)) {
        $safePath = Get-SafeAbsolutePath $Path
        Write-FileWithRetry -FilePath $safePath -Content $key
    }
}

function Remove-ProgressFileIfSafe {
    param(
        [string]$Path,
        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
        Write-Host "Progress file removed: $Path"
        Write-Host "Reason: $Reason"
    }
}

function Start-FileRetryDelay {
    param(
        [int]$MinimumMilliseconds,
        [int]$MaximumMilliseconds
    )

    $min = [Math]::Max(0, $MinimumMilliseconds)
    $max = [Math]::Max($min, $MaximumMilliseconds)

    if ($max -le 0) { return }

    if ($max -eq $min) {
        Start-Sleep -Milliseconds $min
    }
    else {
        Start-Sleep -Milliseconds (Get-Random -Minimum $min -Maximum $max)
    }
}

function Write-FileWithRetry {
    param(
        [string]$FilePath,
        [string]$Content
    )
    $maxAttempts = $Script:FileWriteRetryCount
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            [System.IO.File]::AppendAllText($FilePath, "$Content`n", [System.Text.Encoding]::UTF8)
            return
        }
        catch [System.UnauthorizedAccessException] {
            throw "Cannot write to file (read-only or access denied): $FilePath"
        }
        catch [System.IO.IOException] {
            if ($i -eq $maxAttempts) { throw }
            Start-FileRetryDelay -MinimumMilliseconds $Script:FileWriteRetryDelayMinMs -MaximumMilliseconds $Script:FileWriteRetryDelayMaxMs
        }
    }
}

function Write-FileLinesWithRetry {
    param(
        [string]$FilePath,
        [string[]]$Lines
    )
    $maxAttempts = $Script:FileWriteRetryCount
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            [System.IO.File]::AppendAllLines($FilePath, $Lines, [System.Text.Encoding]::UTF8)
            return
        }
        catch [System.UnauthorizedAccessException] {
            throw "Cannot write to file (read-only or access denied): $FilePath"
        }
        catch [System.IO.IOException] {
            if ($i -eq $maxAttempts) { throw }
            Start-FileRetryDelay -MinimumMilliseconds $Script:FileWriteRetryDelayMinMs -MaximumMilliseconds $Script:FileWriteRetryDelayMaxMs
        }
    }
}

function Remove-FileDuplicatesFast {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $safePath = Get-SafeAbsolutePath $FilePath

    if (-not [System.IO.File]::Exists($safePath)) {
        Write-Warning "File not found: $safePath"
        return
    }

    # Same policy as sorting: skip very large files to avoid unbounded RAM usage.
    # Deduplication streams the file, but the HashSet of seen keys can still grow very large.
    $fileSize = (Get-Item -LiteralPath $safePath).Length
    if ($Script:MaintenanceLargeFileLimitBytes -gt 0 -and $fileSize -gt $Script:MaintenanceLargeFileLimitBytes) {
        $limitMb = [Math]::Round($Script:MaintenanceLargeFileLimitBytes / 1MB)
        Write-Warning "MAINTENANCE SKIPPED: file exceeds maintenance limit of $limitMb MB ($([Math]::Round($fileSize / 1MB)) MB). File left unchanged: $safePath. Use -MaintenanceLargeFileLimitMB 0 or -IgnoreMaintenanceLargeFileLimit to process it anyway."
        return
    }

    # Use a process-unique temp file to prevent conflicts if multiple instances run
    $tempFile = "$safePath.$PID.dedup.tmp"
    $seenKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $reader = $null
    $writer = $null

    Write-Host "Deduplicating file: $safePath"

    try {
        $reader = [System.IO.StreamReader]::new($safePath, [System.Text.Encoding]::UTF8)
        $writer = [System.IO.StreamWriter]::new($tempFile, $false, [System.Text.Encoding]::UTF8)
        $duplicatesRemoved = 0
        $linesKept = 0

        while ($null -ne ($line = $reader.ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            $trimmed = $line.Trim()

            # Pass comments through without dedup
            if ($trimmed.StartsWith("#")) {
                $writer.WriteLine($trimmed)
                $linesKept++
                continue
            }

            # Use Get-LinkKey for URL-aware dedup (respects -KeepFragments)
            $key = Get-LinkKey $trimmed
            if ([string]::IsNullOrWhiteSpace($key)) {
                # Not a valid URL — keep as-is using raw string dedup
                $key = $trimmed
            }

            if ($seenKeys.Add($key)) {
                $writer.WriteLine((Get-LinkWriteValue $trimmed))
                $linesKept++
            }
            else {
                $duplicatesRemoved++
            }
        }

        Write-Host "  Kept: $linesKept | Removed: $duplicatesRemoved"
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $writer) { $writer.Dispose() }
    }

    for ($moveAttempt = 1; $moveAttempt -le $Script:FileMoveRetryCount; $moveAttempt++) {
        try {
            Move-Item -LiteralPath $tempFile -Destination $safePath -Force
            break
        } catch {
            if ($moveAttempt -eq $Script:FileMoveRetryCount) { throw }
            if ($Script:FileMoveRetryDelayMs -gt 0) {
                Start-Sleep -Milliseconds $Script:FileMoveRetryDelayMs
            }
        }
    }
    Write-Host "Deduplication complete."
}

function Sort-FileFast {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Ascending", "Descending")]
        [string]$SortDirection = "Ascending"
    )

    $safePath = Get-SafeAbsolutePath $FilePath

    if (-not [System.IO.File]::Exists($safePath)) { return }

    $fileInfo = Get-Item -LiteralPath $safePath
    if ($fileInfo.Length -eq 0) { return }

    if ($Script:MaintenanceLargeFileLimitBytes -gt 0 -and $fileInfo.Length -gt $Script:MaintenanceLargeFileLimitBytes) {
        $limitMb = [Math]::Round($Script:MaintenanceLargeFileLimitBytes / 1MB)
        Write-Warning "MAINTENANCE SKIPPED: file exceeds maintenance limit of $limitMb MB ($([Math]::Round($fileInfo.Length / 1MB)) MB). File left unchanged: $safePath. Use -MaintenanceLargeFileLimitMB 0 or -IgnoreMaintenanceLargeFileLimit to process it anyway."
        return
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $comments = [System.Collections.Generic.List[string]]::new()

    foreach ($line in [System.IO.File]::ReadLines($safePath, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#")) {
            $comments.Add($trimmed)
        }
        else {
            $lines.Add($trimmed)
        }
    }

    $lines.Sort([System.StringComparer]::OrdinalIgnoreCase)
    if ($SortDirection -eq "Descending") {
        $lines.Reverse()
    }

    $tempFile = "$safePath.$PID.sort.tmp"
    $writer = [System.IO.StreamWriter]::new($tempFile, $false, [System.Text.Encoding]::UTF8)
    try {
        # Write comments first (preserve headers)
        foreach ($c in $comments) { $writer.WriteLine($c) }
        # Then sorted content
        foreach ($l in $lines) { $writer.WriteLine($l) }
    }
    finally {
        $writer.Dispose()
    }

    for ($moveAttempt = 1; $moveAttempt -le $Script:FileMoveRetryCount; $moveAttempt++) {
        try {
            Move-Item -LiteralPath $tempFile -Destination $safePath -Force
            break
        } catch {
            if ($moveAttempt -eq $Script:FileMoveRetryCount) { throw }
            if ($Script:FileMoveRetryDelayMs -gt 0) {
                Start-Sleep -Milliseconds $Script:FileMoveRetryDelayMs
            }
        }
    }
    Write-Host "Sorted: $safePath ($SortDirection, $($lines.Count) lines)"
}

function Get-UniqueMaintenanceFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$FilePath
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $FilePath) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }

        $safePath = Get-SafeAbsolutePath $file
        if ($seen.Add($safePath)) {
            Write-Output $safePath
        }
    }
}

function Test-MaintenancePhaseEnabled {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("None", "Start", "End", "Both")]
        [string]$When,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Start", "End")]
        [string]$Phase
    )

    return ($When -eq $Phase -or $When -eq "Both")
}

function Invoke-FileMaintenance {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$FilePath,

        [Parameter(Mandatory=$false)]
        [bool]$Deduplicate = $false,

        [Parameter(Mandatory=$false)]
        [bool]$Sort = $false,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Ascending", "Descending")]
        [string]$SortDirection = "Ascending"
    )

    if (-not $Deduplicate -and -not $Sort) { return }

    foreach ($file in @(Get-UniqueMaintenanceFiles -FilePath $FilePath)) {
        if (-not [System.IO.File]::Exists($file)) {
            Write-Warning "File not found: $file"
            continue
        }

        if ($Deduplicate) {
            Remove-FileDuplicatesFast -FilePath $file
        }

        if ($Sort) {
            Sort-FileFast -FilePath $file -SortDirection $SortDirection
        }
    }
}

function Get-ProcessingMaintenanceFiles {
    $list = [System.Collections.Generic.List[string]]::new()

    if ($SourceType -eq "File" -and -not [string]::IsNullOrWhiteSpace($Source)) {
        [void]$list.Add($Source)
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        [void]$list.Add($OutputFile)
    }

    if ($BlacklistFile) {
        foreach ($blFile in $BlacklistFile) {
            if (-not [string]::IsNullOrWhiteSpace($blFile)) {
                [void]$list.Add($blFile)
            }
        }
    }

    return @($list)
}

function Invoke-ProcessingMaintenancePhase {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Start", "End")]
        [string]$Phase
    )

    $doDeduplicate = Test-MaintenancePhaseEnabled -When $DeduplicateWhen -Phase $Phase
    $doSort = Test-MaintenancePhaseEnabled -When $SortWhen -Phase $Phase

    if (-not $doDeduplicate -and -not $doSort) { return }

    $filesToMaintain = @(Get-ProcessingMaintenanceFiles)
    if ($filesToMaintain.Count -eq 0) { return }

    Write-Host ""
    Write-Host "--- File maintenance: $Phase phase ---"
    Invoke-FileMaintenance `
        -FilePath $filesToMaintain `
        -Deduplicate:$doDeduplicate `
        -Sort:$doSort `
        -SortDirection $SortDirection
    Write-Host "--- File maintenance complete: $Phase phase ---"
    Write-Host ""
}

# #36: Check if a URL targets a private/internal network (SSRF protection)
function Test-IsPrivateUrl {
    param([string]$Url)
    try {
        $uri = [uri]$Url
        $host_ = $uri.Host

        # Always block localhost regardless of format
        if ($host_ -ieq 'localhost' -or $host_ -eq '[::1]') { return $true }

        # Resolve DNS to catch obfuscated domains mapping to internal IPs
        $ips = $null
        try {
            $ips = [System.Net.Dns]::GetHostAddresses($host_)
        } catch {
            # If DNS fails, the web request will fail natively anyway
            return $false
        }

        foreach ($ip in $ips) {
            if ([System.Net.IPAddress]::IsLoopback($ip)) { return $true }

            $bytes = $ip.GetAddressBytes()
            if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                if ($bytes[0] -eq 127) { return $true }
                if ($bytes[0] -eq 10) { return $true }
                if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) { return $true }
                if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) { return $true }
                if ($bytes[0] -eq 169 -and $bytes[1] -eq 254) { return $true }
                if ($bytes[0] -eq 0) { return $true }
            }
            elseif ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
                if ($ip.IsIPv6LinkLocal -or $ip.IsIPv6SiteLocal) { return $true }
            }
        }
    }
    catch { }
    return $false
}

# #23: Strip UTF-8 BOM from a string if present
function Remove-Bom {
    param([string]$Text)
    if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xFEFF) {
        return $Text.Substring(1)
    }
    return $Text
}

# #28: Validate filename does not contain illegal characters
function Test-ValidFilePath {
    param([string]$Path)
    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    foreach ($c in $invalidChars) {
        if ($Path.Contains($c)) { return $false }
    }
    return $true
}

# Decode JS-escaped URLs (\/ and \u002F).
# Unwraps search engine redirects (Google/Bing) and strips tracking parameters
function Unwrap-SearchEngineLink {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }

    # 1. Google Search Redirects (e.g., /url?q=https://...)
    if ($Url -match '(?i)^(?:https?://(?:www\.)?google\.[a-z.]{2,6})?/url\?.*?[?&](?:q|url)=([^&]+)') {
        $Url = [System.Net.WebUtility]::UrlDecode($matches[1])
    }
    # 2. Bing Click Tracking (e.g., /ck/a?!...&u=a1aHR0cHM...)
    elseif ($Url -match '(?i)^https?://(?:www\.)?bing\.com/ck/a\?.*?&u=([a-zA-Z0-9\-_=]+)') {
        $b64 = $matches[1]
        if ($b64.Length -gt 2) {
            try {
                $b64 = $b64.Substring(2).Replace('-', '+').Replace('_', '/')
                $pad = $b64.Length % 4
                if ($pad -gt 0) { $b64 += '=' * (4 - $pad) }
                $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
                if ($decoded -match '^https?://') { $Url = $decoded }
            } catch { }
        }
    }

    # 3. Generic Return URLs (ru=, dest=, target=)
    if ($Url -match '(?i)[?&](?:ru|dest|target)=([^&]+)') {
        $decoded = [System.Net.WebUtility]::UrlDecode($matches[1])
        if ($decoded -match '^https?://') { $Url = $decoded }
    }

    # 4. Strip tracking parameters (UTM, gclid, fbclid, msclkid)
    if ($Url -match '\?') {
        $Url = $Url -replace '(?i)(?<=[?&])(utm_[a-z]+|gclid|fbclid|msclkid|igshid)=[^&#]*&?', ''
        $Url = $Url -replace '&$', ''
        $Url = $Url -replace '\?$', ''
    }

    return $Url
}

function Decode-JsUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }

    $Value = $Value `
        -replace '\\/', '/' `
        -replace '\\u002[Ff]', '/' `
        -replace '\\u0026', '&' `
        -replace '\\u003[Dd]', '=' `
        -replace '\\u003[Ff]', '?' `
        -replace '\\u0023', '#' `
        -replace '\\u0025', '%' `
        -replace '\\u0040', '@' `
        -replace '\\u003[Aa]', ':' `
        -replace '\\u0022', '"' `
        -replace '\\u0027', "'"

    return $Value
}

function Normalize-Link {
    param(
        [string]$Link,
        [uri]$BaseUri = $null
    )

    if ([string]::IsNullOrWhiteSpace($Link)) { return $null }

    # Fast-fail obvious non-URL strings before doing expensive regex/URI work
    if ($Link.StartsWith("javascript:", [System.StringComparison]::OrdinalIgnoreCase) -or
        $Link.StartsWith("data:", [System.StringComparison]::OrdinalIgnoreCase) -or
        $Link.StartsWith("mailto:", [System.StringComparison]::OrdinalIgnoreCase) -or
        $Link.StartsWith("tel:", [System.StringComparison]::OrdinalIgnoreCase) -or
        $Link.StartsWith("#")) {
        return $null
    }

    $link = [System.Net.WebUtility]::HtmlDecode($Link.Trim())
    # Handle double-encoded entities (&amp;amp; -> &amp; -> &)
    if ($link -match '&\w+;|&#\d+;|&#x[0-9a-fA-F]+;') {
        $link = [System.Net.WebUtility]::HtmlDecode($link)
    }
    $link = $link -replace '[\x00-\x1F\x7F]', ''
    $link = $link.Trim()

    if ([string]::IsNullOrWhiteSpace($link)) { return $null }

    # Unwrap search engine redirects and strip tracking parameters
    $link = Unwrap-SearchEngineLink -Url $link
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
            if ($absolute.Scheme -match '^https?$') { return $absolute.ToString() }
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
        $BlacklistSet
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    if ($null -eq $BlacklistSet -or $BlacklistSet.Count -eq 0) { return $false }

    return $BlacklistSet.ContainsKey((Get-LinkKey $Url))
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
    $session.UserAgent = $UserAgent
    if ($Proxy) {
        $proxyObj = [System.Net.WebProxy]::new($Proxy)
        $proxyUri = [uri]$Proxy
        if (-not [string]::IsNullOrWhiteSpace($proxyUri.UserInfo)) {
            $creds = $proxyUri.UserInfo -split ':', 2
            if ($creds.Count -eq 2) {
                $proxyObj.Credentials = [System.Net.NetworkCredential]::new(
                    [System.Net.WebUtility]::UrlDecode($creds[0]),
                    [System.Net.WebUtility]::UrlDecode($creds[1])
                )
            }
        }
        $session.Proxy = $proxyObj
    }

    $headers = @{
        "Accept"           = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        "Accept-Language"  = "en-GB,en;q=0.9"
        "Accept-Encoding"  = if ($PSVersionTable.PSVersion.Major -ge 7) { "gzip, deflate" } else { "identity" }
        "Cache-Control"    = "no-cache"
    }

    $currentUrl    = $Url
    $maxRedirects  = $Script:MaxRedirects
    $redirectsDone = 0

    # PS7 HttpClient destroys the response object on redirect exceptions,
    # so we can only intercept redirects manually on PS5.1.
    # PS7 follows redirects natively; post-fetch SSRF check catches private IPs.
    $maxRedirParam = if ($PSVersionTable.PSVersion.Major -ge 7) { $Script:MaxRedirects } else { 0 }

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
                    -MaximumRedirection $maxRedirParam `
                    -TimeoutSec $Timeout `
                    -ErrorAction Stop

                # Silent second fetch: wait, re-request with same session,
                # keep the larger body. No extra console output.
                if ($DoSecondFetch) {
                    if ($SecondWait -gt 0) {
                        Start-Sleep -Seconds $SecondWait
                    }
                    $response2 = $null
                    $keepResponse2 = $false
                    try {
                        $response2 = Invoke-WebRequest `
                            -Uri $currentUrl `
                            -WebSession $session `
                            -Headers $headers `
                            -UseBasicParsing `
                            -MaximumRedirection $maxRedirParam `
                            -TimeoutSec $Timeout `
                            -ErrorAction Stop

                        if ([string]($response2.Content).Length -gt [string]($response.Content).Length) {
                            Dispose-BaseResponseSafe $response
                            $response = $response2
                            $keepResponse2 = $true
                        }
                    }
                    catch {
                        # Second fetch failed silently -- use first response
                        # Dispose the response trapped inside the exception
                        $excResponseProp = $_.Exception.PSObject.Properties['Response']
                        if ($null -ne $excResponseProp -and $null -ne $excResponseProp.Value) {
                            Dispose-BaseResponseSafe $excResponseProp.Value
                        }
                    }
                    finally {
                        # Dispose $response2 if it was not promoted to $response
                        if (-not $keepResponse2 -and $null -ne $response2) {
                            Dispose-BaseResponseSafe $response2
                        }
                    }
                }

                # Check for <meta http-equiv="refresh"> redirect (quoted or unquoted)
                $metaRefresh = [regex]::Match(
                    [string]$response.Content,
                    '(?i)<meta[^>]+http-equiv\s*=\s*["'']?refresh["'']?[^>]+content\s*=\s*["'']?\s*\d+\s*;\s*url\s*=\s*["'']*(?<url>[^"''\s>]+)',
                    [System.Text.RegularExpressions.RegexOptions]::Singleline
                )
                if ($metaRefresh.Success) {
                    $nextUrl = $metaRefresh.Groups["url"].Value.Trim()
                    $nextUrl = Normalize-Link -Link $nextUrl -BaseUri ([uri]$currentUrl)
                    if ($nextUrl -and $nextUrl -ne $currentUrl) {
                        Write-Host "  Following meta-refresh redirect -> $nextUrl"
                        Dispose-BaseResponseSafe $response
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

                # Abort immediately for permanent HTTP errors that won't resolve
                $responseObj = $null
                $responseProp = $_.Exception.PSObject.Properties['Response']

                if ($null -ne $responseProp) {
                    $responseObj = $responseProp.Value
                }

                if ($null -ne $responseObj) {
                    $statusProp = $responseObj.PSObject.Properties['StatusCode']

                    if ($null -ne $statusProp) {
                        $statusCode = [int]$statusProp.Value

                        if ($statusCode -in @(401, 403, 404, 410)) {
                            Dispose-BaseResponseSafe $responseObj
                            throw "Permanent HTTP $statusCode error. Aborting retries for $currentUrl."
                        }

                        # Intercept HTTP redirects to validate against SSRF
                        if ($statusCode -in @(301, 302, 303, 307, 308)) {
                            $locProp = $responseObj.PSObject.Properties['Headers']
                            if ($null -ne $locProp -and $null -ne $locProp.Value['Location']) {
                                $rawLoc = $locProp.Value['Location']
                                if ($rawLoc -is [array]) { $rawLoc = $rawLoc[0] }

                                $redirectUrl = Normalize-Link -Link $rawLoc -BaseUri ([uri]$currentUrl)

                                if (Test-IsPrivateUrl $redirectUrl) {
                                    Dispose-BaseResponseSafe $responseObj
                                    throw "SSRF Blocked: Redirect targets private/internal network ($redirectUrl)."
                                }

                                Write-Host "  Following HTTP redirect -> $redirectUrl"
                                Dispose-BaseResponseSafe $responseObj
                                $currentUrl = $redirectUrl
                                $redirectsDone++
                                continue redirectLoop
                            }
                        }

                        # #2: Honour Retry-After header for 429/503
                        if ($statusCode -in @(429, 503)) {
                            $retryAfterProp = $responseObj.PSObject.Properties['Headers']
                            if ($null -ne $retryAfterProp -and $null -ne $retryAfterProp.Value) {
                                $raVal = $retryAfterProp.Value['Retry-After']
                                if ($null -ne $raVal) {
                                    $raSec = 0
                                    if ([int]::TryParse(([string]$raVal).Trim(), [ref]$raSec) -and $raSec -gt 0 -and ($Script:MaxRetryAfterSeconds -eq 0 -or $raSec -le $Script:MaxRetryAfterSeconds)) {
                                        if ($Script:MaxRetryAfterSeconds -eq 0) {
                                            Write-Host "  Server requested Retry-After: $raSec second(s); ignoring because -MaxRetryAfterSeconds is 0."
                                            Dispose-BaseResponseSafe $responseObj
                                            continue
                                        }
                                        Write-Host "  Server requested Retry-After: $raSec second(s)"
                                        Dispose-BaseResponseSafe $responseObj
                                        Start-Sleep -Seconds $raSec
                                        continue
                                    }
                                }
                            }
                        }
                    }

                    # Dispose the trapped response to prevent socket/memory leak
                    Dispose-BaseResponseSafe $responseObj
                }

                if ($attempt -lt $MaxRetries) {
                    $effectiveWait = [Math]::Max(0, $WaitSec)
                    if ($effectiveWait -gt 0) {
                        Write-Host "  Retrying in $effectiveWait second(s) ..."
                        Start-Sleep -Seconds $effectiveWait
                    }
                    else {
                        Write-Host "  Retrying immediately ..."
                    }
                }
            }
        }

        # All retries exhausted for this URL
        throw "All $MaxRetries attempt(s) failed for $currentUrl. Last error: $($lastError.Exception.Message)"
    }

    # Dispose the last response before throwing to prevent memory leak
    Dispose-BaseResponseSafe $response
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

    $response = $null

    try {
        $response = Invoke-WebRequestWithRetry `
            -Url $PageUrl `
            -MaxRetries $RetryCount `
            -WaitSec $WaitSeconds `
            -Timeout $TimeoutSeconds `
            -DoSecondFetch $SecondFetch `
            -SecondWait $SecondFetchWait

        # Force Content-Type to scalar and split comma-separated values
        $contentType = $null
        $ctRaw = $response.Headers["Content-Type"]
        if ($null -ne $ctRaw) {
            if ($ctRaw -is [array]) { $contentType = $ctRaw[0] }
            else { $contentType = [string]$ctRaw }
            # Extract just the media type from "text/html; charset=UTF-8"
            $contentType = ($contentType -split ',')[0].Trim()
        }

        if ($null -ne $contentType) {
            if ($contentType -notmatch '(?i)text|html|json|xml|javascript') {
                Write-Host "  Skipping binary or unsupported content type: $contentType"
                return @()
            }
        }
        else {
            # No Content-Type header: check Content-Length as a safety net
            $clRaw = $response.Headers["Content-Length"]
            if ($null -ne $clRaw) {
                # Handle array Content-Length (misconfigured proxies)
                if ($clRaw -is [array]) { $clRaw = $clRaw[0] }
                $clValue = 0L
                if ([long]::TryParse(([string]$clRaw).Trim(), [ref]$clValue) -and $Script:MaxPageContentBytes -gt 0 -and $clValue -gt $Script:MaxPageContentBytes) {
                    Write-Host "  Skipping: no Content-Type and response exceeds $($Script:MaxPageContentMB) MB ($clValue bytes). Use -MaxPageContentMB 0 to disable this guard."
                    return @()
                }
            }
        }

        $html = [string]$response.Content

        # Additional size guard after content is loaded
        if ($Script:MaxPageContentBytes -gt 0 -and $html.Length -gt $Script:MaxPageContentBytes) {
            Write-Host "  Skipping: page content exceeds $($Script:MaxPageContentMB) MB ($($html.Length) characters). Use -MaxPageContentMB 0 to disable this guard."
            return @()
        }

        # Detect empty 200 OK (possible WAF block or server misconfiguration)
        if ($html.Length -eq 0) {
            Write-Host "  WARNING: Server returned 200 OK but body is empty (possible WAF block)."
            return @()
        }

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

    # SSRF check: ensure redirects didn't land on a private/internal IP
    if (Test-IsPrivateUrl $finalUrl) {
        Write-Host "  BLOCKED: Redirect landed on private/internal URL: $finalUrl"
        return @()
    }

    # Honour <base href="..."> if the page declares one (quoted or unquoted).
    $baseTag = [regex]::Match(
        $html,
        '(?i)<base[^>]+href\s*=\s*(?:["''](?<href>[^"'']+)["'']|(?<href>[^\s"''>]+))'
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

    # #11: Strip HTML comments to avoid extracting dead/commented-out links
    # Strip HTML comments using string manipulation (faster and safer than regex on large payloads)
    $htmlClean = $html
    $commentStart = $htmlClean.IndexOf("<!--")
    while ($commentStart -ge 0) {
        $commentEnd = $htmlClean.IndexOf("-->", $commentStart)
        if ($commentEnd -lt 0) { break }  # Unclosed comment — stop to prevent infinite loop
        $htmlClean = $htmlClean.Remove($commentStart, ($commentEnd - $commentStart + 3))
        $commentStart = $htmlClean.IndexOf("<!--", $commentStart)
    }

    # #12: Extract OpenGraph, Twitter Card, and other meta content URLs
    foreach ($m in [regex]::Matches($htmlClean, '(?i)<meta[^>]+content\s*=\s*["''](?<url>https?://[^"'']+)["'']')) {
        $found.Add($m.Groups["url"].Value)
    }

    # #17: Extract @import url() from <style> blocks
    foreach ($m in [regex]::Matches($htmlClean, '(?i)@import\s+(?:url\()?\s*["'']?(?<url>[^"''\)\s;]+)["'']?\s*\)?')) {
        $val = $m.Groups["url"].Value
        if (-not $val.StartsWith("data:", [System.StringComparison]::OrdinalIgnoreCase)) {
            $found.Add($val)
        }
    }

    # ----- 1. Quoted HTML attributes: href, src, action, data-*, etc. -----
    foreach ($m in $global:RegexAttr.Matches($htmlClean)) {
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
    foreach ($m in $global:RegexUnquotedAttr.Matches($htmlClean)) {
        $found.Add($m.Groups["url"].Value)
    }

    # ----- 2. Raw absolute / protocol-relative / bare URLs anywhere -------
    foreach ($m in $global:RegexRawUrl.Matches($htmlClean)) {
        $found.Add($m.Value)
    }

    # ----- 3. URLs inside <script> blocks (JSON, JS assignments, etc.) ----
    foreach ($scriptMatch in $global:RegexScript.Matches($htmlClean)) {
        $body = $scriptMatch.Groups["body"].Value

        # Quoted strings that look like URLs
        foreach ($m in $global:RegexJsUrl.Matches($body)) {
            $raw = Decode-JsUrl $m.Groups["url"].Value
            # Strip ES6 template literal interpolation markers
            $raw = $raw -replace '\$\{[^}]*\}', ''
            if ($raw -and $raw.Length -gt 4) { $found.Add($raw) }
        }

        # JSON-style "key": "/path/..." or "key": "https://..."
        foreach ($m in $global:RegexJsonPath.Matches($body)) {
            $found.Add((Decode-JsUrl $m.Groups["url"].Value))
        }
    }

    # ----- 4. <noscript> blocks (fallback content for no-JS) --------------
    foreach ($nsMatch in $global:RegexNoscript.Matches($htmlClean)) {
        $nsBody = $nsMatch.Groups["body"].Value
        foreach ($m in $global:RegexAttr.Matches($nsBody)) {
            $found.Add($m.Groups["url"].Value)
        }
        foreach ($m in $global:RegexUnquotedAttr.Matches($nsBody)) {
            $found.Add($m.Groups["url"].Value)
        }
    }

    # ----- 5. CSS url() references ----------------------------------------
    foreach ($m in $global:RegexCssUrl.Matches($htmlClean)) {
        $val = $m.Groups["url"].Value
        # Skip data: URIs early to avoid wasting cycles on base64 blobs
        if (-not $val.StartsWith("data:", [System.StringComparison]::OrdinalIgnoreCase)) {
            $found.Add($val)
        }
    }

    # Normalize everything and remove failed normalisations
    return @(
        @($found).ForEach({ Normalize-Link -Link $_ -BaseUri $baseUri }).Where({ $_ })
    )
    }
    finally {
        # Dispose network streams to prevent resource leaks on long runs
        Dispose-BaseResponseSafe $response
    }
}

# ---------------------------------------------------------------------------
# Pre-compiled regexes for link extraction (compiled once, used per page)
# ---------------------------------------------------------------------------
$global:CompiledRegexOptions = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::ExplicitCapture
$global:RegexTimeout = $Script:RegexTimeout

$global:RegexAttr = [regex]::new(
    '\b(?:href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*["''](?<url>[^"'']+)["'']',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

$global:RegexUnquotedAttr = [regex]::new(
    '\b(?:href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster)\s*=\s*(?<url>[^\s"''>]+)',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

$global:RegexRawUrl = [regex]::new(
    '(?x)
    (?:
        https?://[^\s<>"''\)\]\}]+
      | //[a-z0-9][a-z0-9.-]+\.[a-z]{2,}(?::\d+)?(?:/[^\s<>"''\)\]\}]*)?
      | www\.[^\s<>"''\)\]\}]+
      | (?<![@/\w.-])[a-z0-9][a-z0-9.-]+\.[a-z]{2,}(?::\d+)?(?:/[^\s<>"''\)\]\}]*)?
    )',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

$global:RegexScript = [regex]::new(
    '<script[^>]*>(?<body>.*?)</script>',
    [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
    [System.Text.RegularExpressions.RegexOptions]::Singleline,
    $global:RegexTimeout
)

$global:RegexJsUrl = [regex]::new(
    '(?:"|''|`)(?<url>(?:https?:)?//[^"''`\s]{5,})(?:"|''|`)',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

$global:RegexJsonPath = [regex]::new(
    '"[^"]*"\s*:\s*"(?<url>/[^"]{2,}|https?://[^"]+)"',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

$global:RegexNoscript = [regex]::new(
    '<noscript[^>]*>(?<body>.*?)</noscript>',
    [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
    [System.Text.RegularExpressions.RegexOptions]::Singleline,
    $global:RegexTimeout
)

$global:RegexCssUrl = [regex]::new(
    'url\(\s*["'']?(?<url>[^"''\)\s]+)["'']?\s*\)',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

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
        [string[]]$ExcludeRegexList,
        [ValidateSet("Any", "All")]
        [string]$ExcludeMode,
        [string]$OutFile,
        $WrittenSet,
        $BlacklistSet
    )

    $stats = [pscustomobject]@{
        Matched     = 0
        Excluded    = 0
        Blacklisted = 0
        Duplicates  = 0
        Written     = 0
    }

    # Apply search pattern(s)
    $matched = @($Links.Where({
        Test-LinkMatchesSearch -Link $_ -RegexList $RegexList -Mode $SearchMode
    }))

    $stats.Matched = $matched.Count
    if ($matched.Count -eq 0) { return $stats }

    # Remove links matching exclusion pattern(s), if supplied
    if ($null -ne $ExcludeRegexList -and $ExcludeRegexList.Count -gt 0) {
        $beforeExclude = $matched.Count
        $matched = @($matched.Where({
            -not (Test-LinkMatchesExclude -Link $_ -RegexList $ExcludeRegexList -Mode $ExcludeMode)
        }))
        $stats.Excluded = $beforeExclude - $matched.Count
    }

    if ($matched.Count -eq 0) { return $stats }

    # Remove duplicates within this batch unless told otherwise
    if (-not $KeepDuplicates) {
        $matched = @($matched | Sort-Object -Unique)
    }

    # Skip blacklisted links (only when scope is Output or Both)
    if ((Test-BlacklistAppliesToOutput) -and $BlacklistSet.Count -gt 0) {
        $beforeBl = $matched.Count
        $matched = @($matched.Where({
            -not (Test-IsBlacklisted -Url $_ -BlacklistSet $BlacklistSet)
        }))
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
                if (-not $WrittenSet.ContainsKey($key)) {
                    $toWriteList.Add((Get-LinkWriteValue $link))
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
                    -not $WrittenSet.ContainsKey($key) -and
                    $seenThisBatch.Add($key)
                ) {
                    $toWriteList.Add((Get-LinkWriteValue $link))
                }
            }
        }

        $toWrite = @($toWriteList)
        $stats.Duplicates = $beforeDedup - $toWrite.Count
    }
    else {
        $toWrite = @(@($matched).ForEach({ Get-LinkWriteValue $_ }))
    }

    if ($toWrite.Count -eq 0) { return $stats }

    # Write and track
    $safeOutFile = Get-SafeAbsolutePath $OutFile
    Write-FileLinesWithRetry -FilePath $safeOutFile -Lines ([string[]]$toWrite)

    if ($NoDuplicates) {
        foreach ($link in $toWrite) {
            [void]$WrittenSet.TryAdd((Get-LinkKey $link), [byte]0)
        }
    }

    $stats.Written = $toWrite.Count
    return $stats
}

try {
    # Backward-compatible mapping for the old maintenance switches.
    # New explicit timing options win if both old and new parameters are supplied.
    $legacySortOutputAtEnd = $false

    if ($DeduplicateFiles -and $DeduplicateWhen -eq "None") {
        $DeduplicateWhen = "Start"
    }

    if ($SortOutput -and $SortWhen -eq "None") {
        $legacySortOutputAtEnd = $true

        # Preserve the old combined behaviour: -DeduplicateFiles -SortOutput
        # deduplicated and sorted all involved files before processing, then
        # sorted the output again after the run.
        if ($DeduplicateFiles) {
            $SortWhen = "Start"
        }
    }

    # Standalone maintenance commands. These never fetch/download anything.
    if ($Command -ne "Run") {
        if (-not $Files -or $Files.Count -eq 0) {
            throw "-Files is required when using -Command $Command."
        }

        switch ($Command) {
            "Deduplicate" {
                Write-Host "--- Maintenance command: Deduplicate ---"
                Invoke-FileMaintenance -FilePath $Files -Deduplicate:$true -Sort:$false -SortDirection $SortDirection
            }
            "Sort" {
                Write-Host "--- Maintenance command: Sort ($SortDirection) ---"
                Invoke-FileMaintenance -FilePath $Files -Deduplicate:$false -Sort:$true -SortDirection $SortDirection
            }
            "Maintain" {
                if ($DeduplicateWhen -eq "None" -and $SortWhen -eq "None") {
                    throw "-Command Maintain requires -DeduplicateWhen and/or -SortWhen to be Start, End, or Both."
                }

                # Standalone Maintain has no processing phase between Start and End.
                # Collapse requested operations into one pass to avoid doing identical work twice.
                $doDeduplicate = ($DeduplicateWhen -ne "None")
                $doSort = ($SortWhen -ne "None")

                Write-Host "--- Maintenance command: standalone pass ---"
                Invoke-FileMaintenance `
                    -FilePath $Files `
                    -Deduplicate:$doDeduplicate `
                    -Sort:$doSort `
                    -SortDirection $SortDirection
            }
        }

        Write-Host "--- Maintenance complete. No URLs were fetched. ---"
        exit 0
    }

    if ($Files -and $Files.Count -gt 0) {
        Write-Warning "-Files is ignored when -Command Run is used. Use -Command Deduplicate, Sort, or Maintain for standalone maintenance, or use -DeduplicateWhen/-SortWhen to maintain Source/OutputFile/BlacklistFile during a normal run."
    }

    if ($Resume -and ($Mode -eq "New" -or $LogMode -eq "New" -or $FailedUrlMode -eq "New")) {
        Write-Host "Resume mode forces all output modes from New to Append to prevent data loss."
        $Mode = "Append"
        $LogMode = "Append"
        $FailedUrlMode = "Append"
    }

    if ($Resume -and $SourceType -ne "File") {
        throw "-Resume is only useful with SourceType File."
    }

    if ($ThrottleLimit -gt 1) {
        if ($SourceType -ne "File") {
            throw "-ThrottleLimit > 1 is only useful with SourceType File."
        }
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw "-ThrottleLimit > 1 requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
        }
        Write-Host "Parallel mode enabled: ThrottleLimit = $ThrottleLimit"
    }

    # Assign default progress file early so collision checks also cover it.
    if ($SourceType -eq "File" -and [string]::IsNullOrWhiteSpace($ProgressFile)) {
        $ProgressFile = "$OutputFile.progress"
    }

    # Refuse to start a fresh File-mode run when an old progress file exists.
    # This must happen before output/log files are created or overwritten.
    if (
        $SourceType -eq "File" -and
        $ProgressFile -and
        (Test-Path -LiteralPath $ProgressFile) -and
        -not $Resume
    ) {
        throw "Progress file already exists: $ProgressFile. This usually means a previous run was interrupted. Use -Resume to continue, delete the progress file to start fresh, or specify a different -ProgressFile."
    }

    # #28: Validate output file path for illegal characters
    if (-not (Test-ValidFilePath $OutputFile)) {
        throw "Output file path contains illegal characters: $OutputFile"
    }
    if ($LogCsv -and -not (Test-ValidFilePath $LogCsv)) {
        throw "Log CSV path contains illegal characters: $LogCsv"
    }
    if ($FailedUrlFile -and -not (Test-ValidFilePath $FailedUrlFile)) {
        throw "Failed URL file path contains illegal characters: $FailedUrlFile"
    }

    # Prevent overwriting the source file by mistake
    if ($SourceType -eq "File") {
        $sourceFull = Get-SafeAbsolutePath $Source
        $outputFull = Get-SafeAbsolutePath $OutputFile
        if ($sourceFull -ieq $outputFull) {
            throw "Input file and output file are the same. Refusing to overwrite: $Source"
        }
    }

    # Prevent output/log/failed files from being the same as any blacklist file
    if ($BlacklistFile) {
        $outputFull = Get-SafeAbsolutePath $OutputFile

        if ($LogCsv) {
            $logFull = Get-SafeAbsolutePath $LogCsv
        }

        if ($FailedUrlFile) {
            $failedFull = Get-SafeAbsolutePath $FailedUrlFile
        }

        foreach ($blFile in $BlacklistFile) {
            $blacklistFull = Get-SafeAbsolutePath $blFile

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
        $failedFull = Get-SafeAbsolutePath $FailedUrlFile
        $outputFull = Get-SafeAbsolutePath $OutputFile
        if ($failedFull -ieq $outputFull) {
            throw "Failed URL file and output file are the same: $FailedUrlFile"
        }
        if ($SourceType -eq "File") {
            $sourceFull = Get-SafeAbsolutePath $Source
            if ($failedFull -ieq $sourceFull) {
                throw "Failed URL file and source file are the same: $FailedUrlFile"
            }
        }
    }

    # Prevent LogCsv collisions
    if ($LogCsv) {
        $logFull    = Get-SafeAbsolutePath $LogCsv
        $outputFull = Get-SafeAbsolutePath $OutputFile
        if ($logFull -ieq $outputFull) {
            throw "Log CSV file and output file are the same: $LogCsv"
        }
        if ($SourceType -eq "File") {
            $sourceFull = Get-SafeAbsolutePath $Source
            if ($logFull -ieq $sourceFull) {
                throw "Log CSV file and source file are the same: $LogCsv"
            }
        }
    }

    # Prevent LogCsv == FailedUrlFile
    if ($LogCsv -and $FailedUrlFile) {
        $logFull    = Get-SafeAbsolutePath $LogCsv
        $failedFull = Get-SafeAbsolutePath $FailedUrlFile
        if ($logFull -ieq $failedFull) {
            throw "Log CSV file and failed URL file are the same: $LogCsv"
        }
    }

    # Prevent ProgressFile collisions
    if ($ProgressFile) {
        $progressFull = Get-SafeAbsolutePath $ProgressFile
        $outputFull   = Get-SafeAbsolutePath $OutputFile

        if ($progressFull -ieq $outputFull) {
            throw "Progress file and output file are the same: $ProgressFile"
        }

        if ($SourceType -eq "File") {
            $sourceFull = Get-SafeAbsolutePath $Source
            if ($progressFull -ieq $sourceFull) {
                throw "Progress file and source file are the same: $ProgressFile"
            }
        }

        if ($LogCsv) {
            $logFull = Get-SafeAbsolutePath $LogCsv
            if ($progressFull -ieq $logFull) {
                throw "Progress file and log CSV file are the same: $ProgressFile"
            }
        }

        if ($FailedUrlFile) {
            $failedFull = Get-SafeAbsolutePath $FailedUrlFile
            if ($progressFull -ieq $failedFull) {
                throw "Progress file and failed URL file are the same: $ProgressFile"
            }
        }

        if ($BlacklistFile) {
            foreach ($blFile in $BlacklistFile) {
                $blacklistFull = Get-SafeAbsolutePath $blFile
                if ($progressFull -ieq $blacklistFull) {
                    throw "Progress file and blacklist file are the same: $ProgressFile"
                }
            }
        }
    }


    # Ensure output folder exists
    $folder = Split-Path -Parent $OutputFile
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        [void](New-Item -ItemType Directory -Path $folder -Force)
    }

    if ($Mode -eq "New") {
        Set-Content -LiteralPath $OutputFile -Value @() -Encoding UTF8
        Write-Host "Output file created/overwritten: $OutputFile"
    }
    elseif (-not (Test-Path -LiteralPath $OutputFile)) {
        [void](New-Item -ItemType File -Path $OutputFile -Force)
        Write-Host "Output file created: $OutputFile"
    }

    # Set up FailedUrlFile
    if ($FailedUrlFile) {
        $failedFolder = Split-Path -Parent $FailedUrlFile
        if ($failedFolder -and -not (Test-Path -LiteralPath $failedFolder)) {
            [void](New-Item -ItemType Directory -Path $failedFolder -Force)
        }

        $failedHeader = "SourceUrl`tError"

        if ($FailedUrlMode -eq "New") {
            Set-Content -LiteralPath $FailedUrlFile -Value $failedHeader -Encoding UTF8
            Write-Host "Failed URL file created/overwritten: $FailedUrlFile"
        }
        elseif (-not (Test-Path -LiteralPath $FailedUrlFile)) {
            Set-Content -LiteralPath $FailedUrlFile -Value $failedHeader -Encoding UTF8
            Write-Host "Failed URL file created: $FailedUrlFile"
        }
        else {
            $failedItem = Get-Item -LiteralPath $FailedUrlFile -ErrorAction Stop
            if ($failedItem.Length -eq 0) {
                Set-Content -LiteralPath $FailedUrlFile -Value $failedHeader -Encoding UTF8
                Write-Host "Failed URL file was empty; header added: $FailedUrlFile"
            }
        }
    }

    # Set up LogCsv
    if ($LogCsv) {
        $logFolder = Split-Path -Parent $LogCsv
        if ($logFolder -and -not (Test-Path -LiteralPath $logFolder)) {
            [void](New-Item -ItemType Directory -Path $logFolder -Force)
        }

        $csvHeader = "Timestamp,SourceUrl,Status,Extracted,Matched,Excluded,Blacklisted,Duplicates,Written,Error"

        if ($LogMode -eq "New") {
            Set-Content -LiteralPath $LogCsv -Value $csvHeader -Encoding UTF8
            Write-Host "Log CSV file created/overwritten: $LogCsv"
        }
        elseif (-not (Test-Path -LiteralPath $LogCsv)) {
            Set-Content -LiteralPath $LogCsv -Value $csvHeader -Encoding UTF8
            Write-Host "Log CSV file created: $LogCsv"
        }
        else {
            $logItem = Get-Item -LiteralPath $LogCsv -ErrorAction Stop
            if ($logItem.Length -eq 0) {
                Set-Content -LiteralPath $LogCsv -Value $csvHeader -Encoding UTF8
                Write-Host "Log CSV file was empty; header added: $LogCsv"
            }
            else {
                # #49: Validate existing CSV has matching column structure
                $existingHeader = (Get-Content -LiteralPath $LogCsv -TotalCount 1 -Encoding UTF8)
                if ($existingHeader -and $existingHeader.Trim() -ne $csvHeader) {
                    Write-Host "WARNING: Existing CSV header does not match expected format. Columns may be misaligned."
                    Write-Host "  Expected: $csvHeader"
                    Write-Host "  Found:    $($existingHeader.Trim())"
                }
            }
        }
    }

    # Compute patterns and signature early so resume validation happens before file mutations
    $effectiveSearchPatterns = @(Get-EffectiveSearchPatterns)
    $effectiveExcludePatterns = @(Get-EffectiveExcludePatterns)

    $runSignature = Get-RunSignature `
        -Source $Source `
        -SourceType $SourceType `
        -OutputFile $OutputFile `
        -SearchPatterns $effectiveSearchPatterns `
        -SearchMode $SearchMode `
        -ExcludePatterns $effectiveExcludePatterns `
        -ExcludeMode $ExcludeMode `
        -BlacklistScope $BlacklistScope `
        -BlacklistPaths @($BlacklistFile | Sort-Object) `
        -SecondFetch $SecondFetch `
        -KeepDuplicates $KeepDuplicates `
        -NoDuplicates $NoDuplicates `
        -KeepFragments $KeepFragments

    # Validate resume signature BEFORE any destructive file cleanup
    $completedSourceSet = $null
    if ($SourceType -eq "File" -and $Resume -and $ProgressFile -and (Test-Path -LiteralPath $ProgressFile)) {
        $completedSourceSet = Initialize-ProgressFile `
            -Path $ProgressFile `
            -Signature $runSignature `
            -Resume:$true
    }

    # Optional start-phase file maintenance before loading source/output/blacklist sets.
    Invoke-ProcessingMaintenancePhase -Phase "Start"

    # Build a set of everything already in the output file (for -NoDuplicates).
    $writtenSet = [System.Collections.Concurrent.ConcurrentDictionary[string, byte]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ($NoDuplicates -and (Test-Path -LiteralPath $OutputFile)) {
        try {
            $outPathSafe = Get-SafeAbsolutePath $OutputFile
            # ReadLines creates a streaming enumerable, avoiding memory bloat
            foreach ($line in [System.IO.File]::ReadLines($outPathSafe, [System.Text.Encoding]::UTF8)) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    [void]$writtenSet.TryAdd((Get-LinkKey $line), [byte]0)
                }
            }
            Write-Host "Loaded $($writtenSet.Count) existing link(s) from output file."
        }
        catch {
            Write-Host "WARNING: Failed to read existing output file for deduplication. $($_.Exception.Message)"
        }
    }

    # Load blacklist files into a single set
    $blacklistSet = [System.Collections.Concurrent.ConcurrentDictionary[string, byte]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ($BlacklistFile) {
        foreach ($blFile in $BlacklistFile) {
            if (-not (Test-Path -LiteralPath $blFile)) {
                Write-Host "WARNING: Blacklist file not found, skipping: $blFile"
                continue
            }

            try {
                $blSafePath = Get-SafeAbsolutePath $blFile
                $countBefore = $blacklistSet.Count

                foreach ($blLine in [System.IO.File]::ReadLines($blSafePath, [System.Text.Encoding]::UTF8)) {
                    if (-not [string]::IsNullOrWhiteSpace($blLine) -and
                        -not $blLine.Trim().StartsWith("#")) {
                        $normalized = Normalize-Link -Link $blLine
                        if ($normalized) {
                            [void]$blacklistSet.TryAdd((Get-LinkKey $normalized), [byte]0)
                        }
                    }
                }

                $added = $blacklistSet.Count - $countBefore
                Write-Host "Loaded $added blacklisted URL(s) from: $blFile"
            }
            catch {
                Write-Host "WARNING: Could not read blacklist file or file is locked: $blFile"
            }
        }

        if ($blacklistSet.Count -gt 0) {
            Write-Host "Total blacklisted URLs: $($blacklistSet.Count)"
        }
    }

    # Patterns already computed before DeduplicateFiles; build regex lists
    $searchRegexList = @(
        $effectiveSearchPatterns | ForEach-Object {
            Convert-WildcardToRegex -Pattern $_
        }
    )

    $excludeRegexList = @(
        $effectiveExcludePatterns | ForEach-Object {
            Convert-WildcardToRegex -Pattern $_
        }
    )

    Write-Host "Search pattern(s): $($effectiveSearchPatterns -join ', ')"
    Write-Host "Search mode: $SearchMode"
    if ($effectiveExcludePatterns.Count -gt 0) {
        Write-Host "Exclude pattern(s): $($effectiveExcludePatterns -join ', ')"
        Write-Host "Exclude mode: $ExcludeMode"
    }


    $totalWritten        = 0
    $totalExtracted      = 0
    $totalMatched        = 0
    $totalExcluded       = 0
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
            [int]$Excluded,
            [int]$Blacklisted,
            [int]$Duplicates,
            [int]$Written,
            [string]$ErrorMsg
        )

        if (-not $LogCsv) { return }

        $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        # Escape fields that might contain commas or quotes
        # Sanitize leading characters that Excel interprets as DDE formulas
        $cleanUrl   = $Url
        $cleanError = $ErrorMsg
        if ($cleanUrl -match '^[=+\-@]')   { $cleanUrl   = "'$cleanUrl" }
        if ($cleanError -match '^[=+\-@]') { $cleanError = "'$cleanError" }
        $safeUrl   = '"' + $cleanUrl.Replace('"', '""') + '"'
        $safeError = '"' + $cleanError.Replace('"', '""') + '"'

        $row = "$ts,$safeUrl,$Status,$Extracted,$Matched,$Excluded,$Blacklisted,$Duplicates,$Written,$safeError"
        $safeLogPath = Get-SafeAbsolutePath $LogCsv
        Write-FileWithRetry -FilePath $safeLogPath -Content $row
    }

    if ($SourceType -eq "Url") {
        # Single URL mode -- fetch, filter, write
        $sourceUrl = Normalize-Link -Link $Source

        if ((Test-BlacklistAppliesToInput) -and (Test-IsBlacklisted -Url $sourceUrl -BlacklistSet $blacklistSet)) {
            Write-Host "Source URL is blacklisted. Skipping: $sourceUrl"
            $totalBlacklistSrc++

            Write-LogCsvRow -Url $sourceUrl -Status "BLACKLISTED_SOURCE" `
                -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 1 -Duplicates 0 `
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
                            -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                            -OutFile $OutputFile -WrittenSet $writtenSet `
                            -BlacklistSet $blacklistSet
                $totalMatched        += $stats.Matched
                $totalExcluded       += $stats.Excluded
                $totalBlacklistOut   += $stats.Blacklisted
                $totalDupes          += $stats.Duplicates
                $totalWritten        += $stats.Written

                Write-Host "  Matched: $($stats.Matched) | Excluded: $($stats.Excluded) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written)"

                Write-LogCsvRow -Url $Source -Status "OK" `
                    -Extracted $links.Count -Matched $stats.Matched `
                    -Excluded $stats.Excluded -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                    -Written $stats.Written -ErrorMsg ""
            }
            catch {
                $totalFailed++
                $errorMessage = $_.Exception.Message
                Write-Host "  FAILED: $errorMessage"

                Write-LogCsvRow -Url $Source -Status "FAILED" `
                    -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                    -Written 0 -ErrorMsg $errorMessage

                if ($FailedUrlFile) {
                    $cleanTsvError = $errorMessage -replace "[\r\n\t]+", " "
                    $failedLine = "$Source`t$cleanTsvError"
                    $safeFailedPath = Get-SafeAbsolutePath $FailedUrlFile
                    Write-FileWithRetry -FilePath $safeFailedPath -Content $failedLine
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

        # Stream source file: normalise, deduplicate in a single pass
        $sourceSafePath = Get-SafeAbsolutePath $Source
        $seenSourceUrls = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $urls = [System.Collections.Generic.List[string]]::new()
        $dupeSourceCount = 0

        Write-Host "Streaming source URLs from file..."
        $isFirstLine = $true

        try {
            $fs = [System.IO.FileStream]::new($sourceSafePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
            
            try {
                while ($null -ne ($line = $reader.ReadLine())) {
                    # #23: Strip BOM from first line if present
                    if ($isFirstLine) { $line = Remove-Bom $line; $isFirstLine = $false }
                    if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) { continue }

                    $normalized = Normalize-Link -Link $line
                    if ($normalized) {
                        # #36: Skip private/internal URLs (SSRF protection)
                        if (Test-IsPrivateUrl $normalized) {
                            Write-Host "  Skipping private/internal URL: $normalized"
                            continue
                        }
                        $key = Get-LinkKey $normalized
                        if ($seenSourceUrls.Add($key)) {
                            $urls.Add($normalized)
                        }
                        else {
                            $dupeSourceCount++
                        }
                    }
                }
            }
            finally {
                $reader.Dispose()
                $fs.Dispose()
            }
        }
        catch {
            throw "Failed to read input file: $($_.Exception.Message)"
        }

        Write-Host "Valid unique source URLs: $($urls.Count)"
        if ($dupeSourceCount -gt 0) {
            Write-Host "Removed $dupeSourceCount duplicate source URL(s)."
        }

        if ($urls.Count -eq 0) {
            throw "No valid URLs found in input file."
        }

        # Initialize progress file after confirming source file has valid URLs.
        # runSignature already computed before DeduplicateFiles
        # Only initialize progress file if not already validated during early resume check
        if ($null -eq $completedSourceSet) {
            $completedSourceSet = Initialize-ProgressFile `
                -Path $ProgressFile `
                -Signature $runSignature `
                -Resume:$Resume
        }

        # Remove blacklisted source URLs before fetching
        if ((Test-BlacklistAppliesToInput) -and $blacklistSet.Count -gt 0) {
            $beforeInputBlacklist = $urls.Count

            $blacklistedSourceUrls = @($urls.Where({
                Test-IsBlacklisted -Url $_ -BlacklistSet $blacklistSet
            }))

            $urls = @($urls.Where({
                -not (Test-IsBlacklisted -Url $_ -BlacklistSet $blacklistSet)
            }))

            $blacklistedInputCount = $beforeInputBlacklist - $urls.Count
            if ($blacklistedInputCount -gt 0) {
                Write-Host "Removed $blacklistedInputCount blacklisted source URL(s)."
                $totalBlacklistSrc += $blacklistedInputCount

                foreach ($blacklistedUrl in $blacklistedSourceUrls) {
                    Write-LogCsvRow -Url $blacklistedUrl -Status "BLACKLISTED_SOURCE" `
                        -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 1 -Duplicates 0 `
                        -Written 0 -ErrorMsg ""
                }
            }
        }

        if ($Resume -and $completedSourceSet -and $completedSourceSet.Count -gt 0) {
            $beforeResumeFilter = $urls.Count

            $urls = @($urls.Where({
                -not $completedSourceSet.ContainsKey((Get-LinkKey $_))
            }))

            $skippedByResume = $beforeResumeFilter - $urls.Count

            if ($skippedByResume -gt 0) {
                Write-Host "Skipped $skippedByResume already processed source URL(s) due to -Resume."
            }
        }

        if ($urls.Count -eq 0) {
            if ($Resume) {
                Write-Host "No URLs left to fetch. Everything in this run appears to be already processed or filtered."

                Remove-ProgressFileIfSafe `
                    -Path $ProgressFile `
                    -Reason "Resume found no remaining source URLs to process."

                Write-Host ""
            }
            elseif ((Test-BlacklistAppliesToInput) -and $totalBlacklistSrc -gt 0) {
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
            if ($ThrottleLimit -gt 1) {
                # ---------------------------------------------------------------
                # Parallel mode (PS 7+ only)
                # Workers only fetch pages and extract links.
                # The parent thread handles filtering, writing, logging,
                # and progress centrally to avoid file-lock races.
                # ---------------------------------------------------------------
                $funcNames = @(
                    'Get-SafeAbsolutePath', 'Get-LinkKey', 'Normalize-Link',
                    'Decode-JsUrl', 'Invoke-WebRequestWithRetry',
                    'Get-LinksFromWebPage', 'Dispose-BaseResponseSafe',
                    'Test-IsPrivateUrl', 'Unwrap-SearchEngineLink'
                )
                $funcDefs = @{}
                foreach ($fn in $funcNames) {
                    $funcDefs[$fn] = (Get-Item "function:$fn").ScriptBlock.ToString()
                }

                # Hide -Parallel from PS 5.1 parser using dynamic scriptblock
                # URL iteration is inside the string so dot-sourcing gives direct
                # scope access to $urls/$funcDefs without $input buffering.
                $parallelCode = @'
                $urls | ForEach-Object {
                    [pscustomobject]@{
                        Url             = $_
                        FuncDefs        = $funcDefs
                        RetryCount      = $RetryCount
                        WaitSeconds     = $WaitSeconds
                        TimeoutSeconds  = $TimeoutSeconds
                        SecondFetch     = $SecondFetch
                        SecondFetchWait = $SecondFetchWait
                        UserAgent       = $UserAgent
                        Proxy           = $Proxy
                        DelaySeconds    = $DelaySeconds
                        # Keep MaxUrlLength in the worker state because Get-LinkKey is loaded into workers.
                        # Current workers do not call it directly, but this avoids StrictMode breakage if that changes.
                        MaxUrlLength    = $Script:MaxUrlLength
                        MaxRedirects    = $Script:MaxRedirects
                        MaxRetryAfterSeconds = $Script:MaxRetryAfterSeconds
                        MaxPageContentMB = $Script:MaxPageContentMB
                        MaxPageContentBytes = $Script:MaxPageContentBytes
                        RegexTimeoutSeconds = $RegexTimeoutSeconds
                    }
                } | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                    $url = $_.Url

                    # Recreate operational limits used by worker functions.
                    $Script:MaxUrlLength = $_.MaxUrlLength
                    $Script:MaxRedirects = $_.MaxRedirects
                    $Script:MaxRetryAfterSeconds = $_.MaxRetryAfterSeconds
                    $Script:MaxPageContentBytes = $_.MaxPageContentBytes
                    $Script:MaxPageContentMB = $_.MaxPageContentMB
                    $Script:RegexTimeout = if ($_.RegexTimeoutSeconds -eq 0) {
                        [System.Text.RegularExpressions.Regex]::InfiniteMatchTimeout
                    }
                    else {
                        [TimeSpan]::FromSeconds($_.RegexTimeoutSeconds)
                    }

                    # Recreate functions and regexes in this runspace (only once per worker)
                    $defs = $_.FuncDefs
                    if (-not (Test-Path "function:Get-LinkKey" -ErrorAction SilentlyContinue)) {
                        foreach ($entry in $defs.GetEnumerator()) {
                            Set-Item "function:$($entry.Key)" -Value ([scriptblock]::Create($entry.Value))
                        }

                        # Compile regexes once per worker (live .NET objects cannot cross runspace boundaries)
                        $cOpts = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::ExplicitCapture
                        $tOut = $Script:RegexTimeout
                        $global:RegexTimeout = $tOut
                        $global:RegexAttr = [regex]::new('\b(?:href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*["''](?<url>[^"'']+)["'']', $cOpts, $tOut)
                        $global:RegexUnquotedAttr = [regex]::new('\b(?:href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster)\s*=\s*(?<url>[^\s"''>]+)', $cOpts, $tOut)
                        $global:RegexRawUrl = [regex]::new('(?x)(?:https?://[^\s<>"''\)\]\}]+|//[a-z0-9][a-z0-9.-]+\.[a-z]{2,}(?::\d+)?(?:/[^\s<>"''\)\]\}]*)?|www\.[^\s<>"''\)\]\}]+|(?<![@/\w.-])[a-z0-9][a-z0-9.-]+\.[a-z]{2,}(?::\d+)?(?:/[^\s<>"''\)\]\}]*)?)', $cOpts, $tOut)
                        $global:RegexScript = [regex]::new('<script[^>]*>(?<body>.*?)</script>', $cOpts -bor [System.Text.RegularExpressions.RegexOptions]::Singleline, $tOut)
                        $global:RegexJsUrl = [regex]::new('(?:"|''|`)(?<url>(?:https?:)?//[^"''`\s]{5,})(?:"|''|`)', $cOpts, $tOut)
                        $global:RegexJsonPath = [regex]::new('"[^"]*"\s*:\s*"(?<url>/[^"]{2,}|https?://[^"]+)"', $cOpts, $tOut)
                        $global:RegexNoscript = [regex]::new('<noscript[^>]*>(?<body>.*?)</noscript>', $cOpts -bor [System.Text.RegularExpressions.RegexOptions]::Singleline, $tOut)
                        $global:RegexCssUrl = [regex]::new('url\(\s*["'']?(?<url>[^"''\)\s]+)["'']?\s*\)', $cOpts, $tOut)
                    }

                    # Recreate variables that functions depend on via pipeline object
                    $global:RetryCount       = $_.RetryCount
                    $global:WaitSeconds      = $_.WaitSeconds
                    $global:TimeoutSeconds   = $_.TimeoutSeconds
                    $global:SecondFetch      = $_.SecondFetch
                    $global:SecondFetchWait  = $_.SecondFetchWait
                    $global:UserAgent        = $_.UserAgent
                    $global:Proxy            = $_.Proxy
                    $ProgressPreference = 'SilentlyContinue'
                    $ErrorActionPreference = 'Stop'
                    $WarningPreference = 'SilentlyContinue'
                    $InformationPreference = 'SilentlyContinue'
                    $VerbosePreference = 'SilentlyContinue'

                    # Rate-limit: stagger parallel requests if DelaySeconds is set
                    $delayMs = $_.DelaySeconds
                    if ($delayMs -gt 0) {
                        $maxDelayMs = [Math]::Min([int]($delayMs * 1000), [int]::MaxValue - 1)
                        Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum $maxDelayMs)
                    }

                    try {
                        $links = @(Get-LinksFromWebPage -PageUrl $url)
                        Write-Host "[parallel] OK: $url -- Extracted $($links.Count) link(s)"

                        [pscustomobject]@{
                            Url      = $url
                            Links    = $links
                            Status   = "OK"
                            ErrorMsg = ""
                        }
                    }
                    catch {
                        Write-Host "[parallel] FAILED: $url -- $($_.Exception.Message)"

                        [pscustomobject]@{
                            Url      = $url
                            Links    = @()
                            Status   = "FAILED"
                            ErrorMsg = $_.Exception.Message
                        }
                    }
                } | ForEach-Object {
                    # Parent thread: filter, write, log, progress — all central, no races
                    $r = $_

                    try {
                    if ($r.Status -eq "OK") {
                        $resultLinks = @($r.Links)
                        $totalExtracted += $resultLinks.Count

                        $stats = Write-MatchedLinks -Links $resultLinks -RegexList $searchRegexList `
                                    -SearchMode $SearchMode `
                                    -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                                    -OutFile $OutputFile -WrittenSet $writtenSet `
                                    -BlacklistSet $blacklistSet
                        $totalMatched      += $stats.Matched
                        $totalExcluded     += $stats.Excluded
                        $totalBlacklistOut += $stats.Blacklisted
                        $totalDupes        += $stats.Duplicates
                        $totalWritten      += $stats.Written

                        Write-Host "  Matched: $($stats.Matched) | Excluded: $($stats.Excluded) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written) -- $($r.Url)"

                        Write-LogCsvRow -Url $r.Url -Status "OK" `
                            -Extracted $resultLinks.Count -Matched $stats.Matched `
                            -Excluded $stats.Excluded -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                            -Written $stats.Written -ErrorMsg ""
                    }
                    else {
                        $totalFailed++
                        $safeErrorMsg = if ([string]::IsNullOrWhiteSpace($r.ErrorMsg)) { "Unknown Network Error" } else { $r.ErrorMsg }

                        Write-LogCsvRow -Url $r.Url -Status "FAILED" `
                            -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                            -Written 0 -ErrorMsg $safeErrorMsg

                        if ($FailedUrlFile) {
                            $cleanTsvError = $safeErrorMsg -replace "[\r\n\t]+", " "
                            $failedLine = "$($r.Url)`t$cleanTsvError"
                            $safeFailedPath = Get-SafeAbsolutePath $FailedUrlFile
                            Write-FileWithRetry -FilePath $safeFailedPath -Content $failedLine
                        }
                    }

                    if ($ProgressFile -and $completedSourceSet) {
                        Add-CompletedProgress `
                            -Path $ProgressFile `
                            -Url $r.Url `
                            -CompletedSet $completedSourceSet
                    }
                    }
                    catch {
                        $totalFailed++
                        $safeErrMsg = $_.Exception.Message
                        Write-Host "  ERROR processing result for $($r.Url): $safeErrMsg"

                        Write-LogCsvRow -Url $r.Url -Status "FAILED" `
                            -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                            -Written 0 -ErrorMsg $safeErrMsg

                        if ($FailedUrlFile) {
                            $cleanTsvError = $safeErrMsg -replace "[\r\n\t]+", " "
                            $failedLine = "$($r.Url)`t$cleanTsvError"
                            $safeFailedPath = Get-SafeAbsolutePath $FailedUrlFile
                            try { Write-FileWithRetry -FilePath $safeFailedPath -Content $failedLine } catch { }
                        }
                    }
                }
'@
                . ([scriptblock]::Create($parallelCode))
            }
            else {
                # ---------------------------------------------------------------
                # Sequential mode (default)
                # ---------------------------------------------------------------
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
                                    -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                                    -OutFile $OutputFile -WrittenSet $writtenSet `
                                    -BlacklistSet $blacklistSet
                        $totalMatched        += $stats.Matched
                        $totalExcluded       += $stats.Excluded
                        $totalBlacklistOut   += $stats.Blacklisted
                        $totalDupes          += $stats.Duplicates
                        $totalWritten        += $stats.Written

                        Write-Host "  Matched: $($stats.Matched) | Excluded: $($stats.Excluded) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written)"

                        Write-LogCsvRow -Url $url -Status "OK" `
                            -Extracted $links.Count -Matched $stats.Matched `
                            -Excluded $stats.Excluded -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                            -Written $stats.Written -ErrorMsg ""
                    }
                    catch {
                        $totalFailed++
                        $errorMessage = $_.Exception.Message

                        Write-Host "  FAILED: $errorMessage"
                        Write-Host "  Skipping this URL and continuing."

                        Write-LogCsvRow -Url $url -Status "FAILED" `
                            -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                            -Written 0 -ErrorMsg $errorMessage

                        if ($FailedUrlFile) {
                            $cleanTsvError = $errorMessage -replace "[\r\n\t]+", " "
                            $failedLine = "$url`t$cleanTsvError"
                            $safeFailedPath = Get-SafeAbsolutePath $FailedUrlFile
                            Write-FileWithRetry -FilePath $safeFailedPath -Content $failedLine
                        }
                    }

                    if ($ProgressFile -and $completedSourceSet) {
                        Add-CompletedProgress `
                            -Path $ProgressFile `
                            -Url $url `
                            -CompletedSet $completedSourceSet
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
    }
    else {
        throw "Unsupported SourceType: $SourceType"
    }

    # Clean up progress file after a normal completed run
    if ($SourceType -eq "File" -and $ProgressFile -and (Test-Path -LiteralPath $ProgressFile)) {
        Remove-ProgressFileIfSafe `
            -Path $ProgressFile `
            -Reason "Run completed normally."
    }

    # Optional end-phase file maintenance after processing has finished.
    Invoke-ProcessingMaintenancePhase -Phase "End"

    # Legacy -SortOutput behaviour: output-file-only sort after processing.
    if ($legacySortOutputAtEnd -and (Test-Path -LiteralPath $OutputFile)) {
        Sort-FileFast -FilePath $OutputFile -SortDirection $SortDirection
    }

    Write-Host "--- Done ---"
    Write-Host "Total links extracted:       $totalExtracted"
    Write-Host "Total matched pattern(s):    $totalMatched"
    Write-Host "Total excluded pattern(s):   $totalExcluded"
    Write-Host "Total blacklisted (source):  $totalBlacklistSrc"
    Write-Host "Total blacklisted (output):  $totalBlacklistOut"
    Write-Host "Total duplicates:            $totalDupes"
    Write-Host "Total written to file:       $totalWritten"
    Write-Host "Total failed URLs:           $totalFailed"
    # #46: Warn if failure rate is suspiciously high
    if ($HighFailureRatePercent -gt 0 -and $SourceType -eq "File" -and $totalFailed -gt 0 -and $urls.Count -gt 0) {
        $failRate = [Math]::Round(($totalFailed / $urls.Count) * 100, 1)
        if ($failRate -ge $HighFailureRatePercent) {
            Write-Host "WARNING: High failure rate ($failRate%). Threshold: $HighFailureRatePercent%. Check your source URLs or network."
        }
    }
    Write-Host "Output file: $OutputFile"
    if ($ProgressFile -and (Test-Path -LiteralPath $ProgressFile)) {
        Write-Host "Progress file: $ProgressFile"
    }
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