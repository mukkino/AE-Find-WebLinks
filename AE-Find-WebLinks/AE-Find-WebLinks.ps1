#requires -Version 5.1

# AE-Find-WebLinks.ps1 - 1.7.1
# Author: Fabio Lichinchi (mukka)
# Site: alterego.cc
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

# ==============================================================================
# SCRIPT PARAMETERS
# Defines all inputs for the script, including targets, patterns, limits, and modes.
# ==============================================================================
param(
    # The target to scrape (URL) or the file containing a list of URLs
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Source,

    # Primary string/wildcard to look for in extracted links
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$SearchPattern,

    # Multiple strings/wildcards to look for
    [Parameter(Mandatory = $false)]
    [string[]]$SearchPatterns,

    # Dictates if ANY search pattern can match, or if ALL must match
    [Parameter(Mandatory = $false)]
    [ValidateSet("Any", "All")]
    [string]$SearchMode = "Any",

    # Pattern used to reject links that matched the search criteria
    [Parameter(Mandatory = $false)]
    [string]$ExcludePattern,

    # Multiple patterns used to reject links
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePatterns,

    # Dictates if ANY exclude pattern triggers rejection, or if ALL must be present
    [Parameter(Mandatory = $false)]
    [ValidateSet("Any", "All")]
    [string]$ExcludeMode = "Any",

    # Where to save the successfully matched links
    [Parameter(Mandatory = $false, Position = 2)]
    [string]$OutputFile,

    # Append to existing file or overwrite/create New
    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateSet("Append", "New")]
    [string]$Mode = "Append",

    # Specifies whether the $Source is a direct URL or a File of URLs
    [Parameter(Mandatory = $false, Position = 4)]
    [ValidateSet("Url", "File")]
    [string]$SourceType = "Url",

    # Network retry logic controls
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$RetryCount = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$WaitSeconds = 30,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$TimeoutSeconds = 120,

    # Delay between fetching different URLs when processing a file list or crawl frontier
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$DelaySeconds = 5,

    # Crawl/follow controls. Defaults preserve the old behaviour: fetch only the supplied source page(s).
    # FollowDepth is link-hop depth: 0 = source page(s) only/no crawl, 1 = also fetch links found on source page(s), etc.
    # -1 is accepted as shorthand for crawling until the allowed frontier is exhausted.
    [Parameter(Mandatory = $false)]
    [ValidateRange(-1, 2147483647)]
    [int]$FollowDepth = 0,

    # Crawl until no more allowed links are discovered instead of stopping at a fixed hop depth.
    # This still obeys FollowScope, FollowPathScope, FollowSubdomains, MaxSubdomainDepth,
    # blacklist/private URL checks, static-asset skipping, robots.txt when enabled, and MaxFollowPages.
    [Parameter(Mandatory = $false)]
    [Alias("FollowToEnd", "UnlimitedFollowDepth")]
    [switch]$FollowUntilExhausted,

    # SameDomain uses an approximate registrable-domain/eTLD+1 boundary; see helper comments below.
    [Parameter(Mandatory = $false)]
    [ValidateSet("SameDomain", "SameHost", "Any")]
    [string]$FollowScope = "SameDomain",

    # Optional path/subtree boundary layered on top of FollowScope.
    # Any = old behaviour. SeedPath = only follow URLs whose path is the seed
    # path itself or a descendant path. Example seed /1 allows /1 and /1/2,
    # but not /2 or /10.
    [Parameter(Mandatory = $false)]
    [ValidateSet("Any", "SeedPath")]
    [string]$FollowPathScope = "Any",

    # When FollowScope is SameDomain, this controls whether non-seed subdomains are crawlable.
    # By default only the seed host(s), the apex/root domain, and www.<root> are followed.
    [Parameter(Mandatory = $false)]
    [bool]$FollowSubdomains = $false,

    # Only used when -FollowSubdomains is true. Default 1 means direct
    # subdomains only; 0 = no subdomain-depth limit. Example with root
    # example.com: depth 1 allows blog.example.com; depth 2 also allows
    # deep.blog.example.com.
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxSubdomainDepth = 1,

    # Safety cap for crawling. 0 = no cap. Applies only when crawl mode is enabled.
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxFollowPages = 1000,

    # Opt-in robots.txt enforcement. Off by default to preserve existing behaviour.
    # When enabled, robots.txt is checked before fetching source URLs, crawl URLs,
    # and HTTP/meta-refresh redirect targets.
    [Parameter(Mandatory = $false)]
    [switch]$EnforceRobotsTxt,

    # Product token used to match User-agent groups in robots.txt when
    # -EnforceRobotsTxt is enabled. This is intentionally separate from the HTTP
    # User-Agent header, which may be a full browser-style string.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RobotsUserAgent = "AE-Find-WebLinks",

    # Fetches the same URL twice to bypass simple cookie-walls or anti-bot screens
    [Parameter(Mandatory = $false)]
    [bool]$SecondFetch = $true,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$SecondFetchWait = 5,

    # Flag to retain duplicate links found on the SAME page
    [Parameter(Mandatory = $false)]
    [switch]$KeepDuplicates,

    # Global dedup flag across output files
    [Parameter(Mandatory = $false)]
    [bool]$NoDuplicates = $true,

    # File containing domains/URLs to ignore entirely
    [Parameter(Mandatory = $false)]
    [string[]]$BlacklistFile,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Input", "Output", "Both")]
    [string]$BlacklistScope = "Both",

    # Multi-threading control (requires PowerShell 7+)
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$ThrottleLimit = 1,

    # Continue an interrupted run using a progress file
    [Parameter(Mandatory = $false)]
    [switch]$Resume,

    # Legacy cleanup flag
    [Parameter(Mandatory = $false)]
    [switch]$DeduplicateFiles,

    # Include #anchor fragments when considering uniqueness
    [Parameter(Mandatory = $false)]
    [switch]$KeepFragments,

    # Removes regex-matched text from extracted links before matching, exclude checks,
    # output blacklist checks, output deduplication, and writing. Example regex: '/\d+$'
    [Parameter(Mandatory = $false)]
    [Alias("UseEvaluationStripRegex", "EnableEvaluationStripRegex")]
    [switch]$StripRegexBeforeEvaluation,

    # Regex removed when -StripRegexBeforeEvaluation is enabled.
    [Parameter(Mandatory = $false)]
    [Alias("EvaluationStripRegex", "LinkEvaluationRegex", "IgnoreRegexForEvaluation")]
    [string]$LinkEvaluationStripRegex,

    [Parameter(Mandatory = $false)]
    [string]$Proxy,

    [Parameter(Mandatory = $false)]
    [bool]$SortOutput = $false,

    # Determines main script action: fetch links, or just run file maintenance
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

    # Disguises the script as a standard web browser
    [Parameter(Mandatory = $false)]
    [string]$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",

    # File tracking paths
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
    # Prevents loading massive files into RAM during deduplication.
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaintenanceLargeFileLimitMB = 1024,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreMaintenanceLargeFileLimit,

    # Protects memory against infinitely large web page payloads
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxPageContentMB = 50,

    # Regex protection against catastrophic backtracking
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$RegexTimeoutSeconds = 10,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxUrlLength = 8192,

    # Limits infinite redirect loops
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$MaxRedirects = 10,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2147483647)]
    [int]$MaxRetryAfterSeconds = 300,

    # I/O resilience for file operations
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
    [double]$HighFailureRatePercent = 50,

    # Help triggers
    [Parameter(Mandatory = $false)]
    [Alias("h")]
    [switch]$Help,

    [Parameter(Mandatory = $false)]
    [Alias("Interactive")]
    [switch]$InteractiveHelp
)

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================
# Enforce strict parsing rules to catch undeclared variables
Set-StrictMode -Version Latest
# Make all errors terminating so we can catch them cleanly
$ErrorActionPreference = "Stop"
# Suppress the visual progress bar which massively slows down Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

# Help-only flows (-Help, -InteractiveHelp, or no parameters at all) should
# never be blocked by operational validation meant for real runs. Detect them
# up-front and let downstream guardrails skip themselves.
$Script:SkipOperationalValidation = $Help -or $InteractiveHelp -or ($PSBoundParameters.Count -eq 0)

# Effective crawl mode. Keep -FollowDepth 0 as "no crawl" because that is the
# default requested for link following and preserves old commands. Unlimited
# crawling is explicit: use -FollowUntilExhausted or -FollowDepth -1.
$Script:FollowDepthUnlimited = ([bool]$FollowUntilExhausted -or $FollowDepth -lt 0)
$Script:CrawlEnabled = ($FollowDepth -gt 0 -or $Script:FollowDepthUnlimited)
$Script:FollowDepthDisplay = if ($Script:FollowDepthUnlimited) { "until exhausted" } else { [string]$FollowDepth }

if (-not $Script:SkipOperationalValidation -and [bool]$FollowUntilExhausted -and $FollowDepth -gt 0) {
    throw "Use either -FollowUntilExhausted/-FollowToEnd or a positive -FollowDepth value, not both. For unlimited crawling, use -FollowUntilExhausted, -FollowToEnd, or -FollowDepth -1."
}

# Validate logical sequence of I/O retry limits
if (-not $Script:SkipOperationalValidation -and $FileWriteRetryDelayMinMs -gt $FileWriteRetryDelayMaxMs) {
    throw "-FileWriteRetryDelayMinMs cannot be greater than -FileWriteRetryDelayMaxMs."
}

# ---------------------------------------------------------------------------
# Function: Assert-OperationalGuardrail
# Purpose: Prevents massive parameter typos from crashing the machine by 
#          throwing an error if a parameter exceeds a safe hardcoded limit.
# ---------------------------------------------------------------------------
function Assert-OperationalGuardrail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [long]$Value,

        [Parameter(Mandatory = $true)]
        [long]$SafeMaximum
    )

    if ($Script:SkipOperationalValidation) { return }
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
Assert-OperationalGuardrail -Name "FollowDepth" -Value $FollowDepth -SafeMaximum 10
Assert-OperationalGuardrail -Name "MaxSubdomainDepth" -Value $MaxSubdomainDepth -SafeMaximum 100
Assert-OperationalGuardrail -Name "MaxFollowPages" -Value $MaxFollowPages -SafeMaximum 1000000
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

# Configure .NET network defaults for higher throughput and modern security
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

# Hard wait cap for DNS resolution inside the SSRF guard. Synchronous DNS calls
# block the worker thread on the OS resolver default (often 15-30s); a
# tarpit/slowloris authoritative server can use that to stall the script.
# Tunable here rather than as a parameter because it is a security guard, not
# a routine knob. Five seconds comfortably covers normal authoritative servers.
[int]$Script:DnsResolutionTimeoutSeconds = 5

# robots.txt cache is per process/runspace and keyed by origin (scheme + host + port).
# Enforcement is opt-in via -EnforceRobotsTxt.
[int]$Script:MaxRobotsTxtBytes = 512000
$Script:RobotsTxtCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

$Script:RegexTimeout = if ($RegexTimeoutSeconds -eq 0) {
    # Infinite match timeout means catastrophic backtracking on a crafted URL
    # can lock the worker thread inside unmanaged regex code, where Ctrl+C
    # cannot interrupt cleanly until the engine yields back to managed code.
    # The user opted into this explicitly, so we honour it -- but warn loudly.
    Write-Warning "-RegexTimeoutSeconds 0 disables the regex match timeout. Pathological page content can lock a worker thread until the process is killed; Ctrl+C may not interrupt while the .NET regex engine is in unmanaged code. Set a finite value when scraping untrusted pages."
    [System.Text.RegularExpressions.Regex]::InfiniteMatchTimeout
}
else {
    [TimeSpan]::FromSeconds($RegexTimeoutSeconds)
}

# Optional URL evaluation cleanup. This is not an exclude filter: it creates a
# temporary/evaluated form of each extracted link by removing a regex match before
# search matching, exclude matching, output blacklist checks, output deduplication,
# and output writing. The actual fetched source/crawl URL is not rewritten.
[bool]$Script:StripRegexBeforeEvaluation = $false
[string]$Script:LinkEvaluationStripRegexText = $null
$Script:LinkEvaluationStripRegexObject = $null
[bool]$Script:LinkEvaluationStripRegexWarned = $false

if (-not $Script:SkipOperationalValidation) {
    if ((-not [bool]$StripRegexBeforeEvaluation) -and -not [string]::IsNullOrWhiteSpace($LinkEvaluationStripRegex)) {
        Write-Warning "-LinkEvaluationStripRegex was supplied without -StripRegexBeforeEvaluation; enabling regex stripping before link evaluation."
        $StripRegexBeforeEvaluation = $true
    }

    if ([bool]$StripRegexBeforeEvaluation) {
        if ([string]::IsNullOrWhiteSpace($LinkEvaluationStripRegex)) {
            throw "-StripRegexBeforeEvaluation requires -LinkEvaluationStripRegex. Example: -StripRegexBeforeEvaluation -LinkEvaluationStripRegex '/\d+$'"
        }

        try {
            $evaluationRegexOptions = [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            $Script:LinkEvaluationStripRegexObject = [regex]::new($LinkEvaluationStripRegex, $evaluationRegexOptions, $Script:RegexTimeout)
            $Script:LinkEvaluationStripRegexText = $LinkEvaluationStripRegex
            $Script:StripRegexBeforeEvaluation = $true
        }
        catch {
            throw "Invalid -LinkEvaluationStripRegex '$LinkEvaluationStripRegex': $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------------------
# Function: Show-Usage
# Purpose: Prints the help menu to the console.
# ---------------------------------------------------------------------------
function Show-Usage {
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  Help and command builder:"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Help"
    Write-Host "  .\AE-Find-WebLinks.ps1 -InteractiveHelp"
    Write-Host ""
    Write-Host "  Run / scrape mode:"
    Write-Host "  .\AE-Find-WebLinks.ps1 <Source> <SearchPattern> <OutputFile> [Mode] [SourceType] [options]"
    Write-Host "  .\AE-Find-WebLinks.ps1 <Source> -SearchPatterns <patterns> -OutputFile <OutputFile> [options]"
    Write-Host ""
    Write-Host "  Maintenance-only mode, no downloading:"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Deduplicate -Files <f1>,<f2>"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Sort -Files <f1>,<f2> [-SortDirection Ascending|Descending]"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Maintain -Files <f1>,<f2> -DeduplicateWhen <Start|End|Both> -SortWhen <Start|End|Both>"
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
    Write-Host "  -StripRegexBeforeEvaluation  Remove a regex match from links before matching/output/dedup."
    Write-Host "  -LinkEvaluationStripRegex <regex> Regex used by -StripRegexBeforeEvaluation. Example: '/\d+$'"
    Write-Host ""
    Write-Host "Mode (optional, default: Append):"
    Write-Host "  New       Create or overwrite the output file, then write matched links."
    Write-Host "  Append    Add matched links to the end of the output file. If the file"
    Write-Host "            does not exist it is created."
    Write-Host ""
    Write-Host "SourceType (optional, default: Url):"
    Write-Host "  Url       Source is a single web page URL. The script fetches that one"
    Write-Host "            page and extracts all links from it."
    Write-Host "  File      Source is a text file containing URLs. Standard format is one"
    Write-Host "            URL per line; multiple URLs on one line are also accepted."
    Write-Host "            The script reads every URL from the file, deduplicates them,"
    Write-Host "            fetches each page one by one, and extracts links from all of"
    Write-Host "            them. Results are written to the output file after each page."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help                     Show this help and exit"
    Write-Host "  -InteractiveHelp          Start the guided command builder and exit"
    Write-Host "  -RetryCount <n>            Number of retry attempts per URL (default: 3)"
    Write-Host "  -WaitSeconds <n>           Seconds to wait between retries of the same URL (default: 30)"
    Write-Host "  -TimeoutSeconds <n>        HTTP timeout per request attempt (default: 120)"
    Write-Host "  -DelaySeconds <n>          Seconds to wait between different URLs in File/crawl mode (default: 5)"
    Write-Host "  -FollowDepth <n>           Link-hop depth. 0 = none/default; -1 = until exhausted"
    Write-Host "  -FollowUntilExhausted      Crawl until no new allowed pages remain (aliases: -FollowToEnd, -UnlimitedFollowDepth)"
    Write-Host "  -FollowScope <scope>       Host/domain crawl boundary: SameDomain, SameHost, or Any (default: SameDomain)"
    Write-Host "  -FollowPathScope <scope>   Path crawl boundary: Any or SeedPath (default: Any)"
    Write-Host "  -FollowSubdomains <bool>   In SameDomain mode, follow non-seed subdomains (default: false)"
    Write-Host "  -MaxSubdomainDepth <n>     Max subdomain labels when FollowSubdomains is true. Default: 1; 0 = no limit"
    Write-Host "  -MaxFollowPages <n>        Safety cap for crawled pages when crawl mode is enabled (default: 1000, 0 = no cap)"
    Write-Host "  -EnforceRobotsTxt         Enforce robots.txt before fetching URLs/redirect targets (default: off)"
    Write-Host "  -RobotsUserAgent <token>  robots.txt User-agent product token (default: AE-Find-WebLinks)"
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
    Write-Host "  -StripRegexBeforeEvaluation  Strip regex matches from links before search/exclude/output evaluation"
    Write-Host "  -LinkEvaluationStripRegex <regex> Regex removed before evaluation. Example: '/\d+$' strips a numeric final path segment"
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
    Write-Host "  -MaxUrlLength <n>                       Max extracted URL length before skipping; dedup key truncation guard (default: 8192, 0 = no limit)"
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
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Deduplicate -Files .\a.txt,.\b.txt"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Sort -Files .\a.txt,.\b.txt -SortDirection Descending"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Deduplicate -Files .\huge.txt -MaintenanceLargeFileLimitMB 0"
    Write-Host "  .\AE-Find-WebLinks.ps1 -Command Maintain -Files .\a.txt,.\b.txt -DeduplicateWhen Start -SortWhen End"
    Write-Host "  .\AE-Find-WebLinks.ps1 .\urls.txt `"*zip*`" .\matches.txt Append File -DeduplicateWhen Start -SortWhen End"
    Write-Host ""
    Write-Host "Resume behaviour:"
    Write-Host "  In File mode, the script writes each completed source URL to a progress file."
    Write-Host "  If interrupted, rerun with -Resume to skip already processed source URLs."
    Write-Host "  Failed URLs are written to -FailedUrlFile if supplied, but are not marked complete."
    Write-Host "  This lets -Resume retry failed or unfinished URLs instead of silently skipping them."
    Write-Host "  The resume signature detects if search/exclude/output settings have changed."
    Write-Host ""
    Write-Host "Examples -- single URL (SourceType = Url):"
    Write-Host ""
    Write-Host "  Fetch one page, find sport links, write to a new file:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://www.bbc.co.uk/news`" `"*sport*`" `"C:\Temp\bbc-links.txt`" New"
    Write-Host ""
    Write-Host "  Fetch one page, find politics links, append to the same file:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://www.bbc.co.uk/news`" `"*politics*`" `"C:\Temp\bbc-links.txt`""
    Write-Host ""
    Write-Host "  Same but with custom retry settings:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"bbc.co.uk/news`" `"*weather*`" `".\bbc-links.txt`" -WaitSeconds 60 -RetryCount 5"
    Write-Host ""
    Write-Host "Examples -- list of URLs (SourceType = File):"
    Write-Host ""
    Write-Host "  Read URLs from a text file, fetch every page, find sport links:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"C:\Temp\urls.txt`" `"*sport*`" `"C:\Temp\matched.txt`" New File"
    Write-Host ""
    Write-Host "  Same but append to existing output:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"C:\Temp\urls.txt`" `"*news*`" `"C:\Temp\matched.txt`" Append File"
    Write-Host ""
    Write-Host "Examples -- multiple search patterns:"
    Write-Host ""
    Write-Host "  Match links containing news OR sport OR weather (Any mode, default):"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"bbc.co.uk`" `"*news*`" `"out.txt`" -SearchPatterns `"*sport*`",`"*weather*`""
    Write-Host ""
    Write-Host "  Match links containing BOTH news AND 2026 (All mode):"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"bbc.co.uk`" `"*news*`" `"out.txt`" -SearchPatterns `"*2026*`" -SearchMode All"
    Write-Host ""
    Write-Host "  Use only -SearchPatterns, without a main positional SearchPattern:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"bbc.co.uk`" -SearchPatterns `"*news*`",`"*sport*`" -OutputFile `"out.txt`""
    Write-Host ""
    Write-Host "Examples -- include and exclude wildcard patterns:"
    Write-Host ""
    Write-Host "  Save links containing download OR game, but exclude demo and trailer links:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" -SearchPatterns `"*download*`",`"*game*`" -ExcludePatterns `"*demo*`",`"*trailer*`" -OutputFile `"matched.txt`" Append File"
    Write-Host ""
    Write-Host "  Save links containing BOTH amiga AND lha, but exclude links containing beta:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" -SearchPatterns `"*amiga*`",`"*lha*`" -SearchMode All -ExcludePattern `"*beta*`" -OutputFile `"matched.txt`" Append File"
    Write-Host ""
    Write-Host "  Exclude only when BOTH unwanted words are present in the same link:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" `"*download*`" `"matched.txt`" Append File -ExcludePatterns `"*demo*`",`"*trial*`" -ExcludeMode All"
    Write-Host ""
    Write-Host "  With CSV log and failed URL tracking (fresh log files, append output):"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" `"*news*`" `"matched.txt`" Append File -LogCsv `"run-log.csv`" -LogMode New -FailedUrlFile `"failed.txt`" -FailedUrlMode New"
    Write-Host ""
    Write-Host "Examples -- crawling/following links:"
    Write-Host ""
    Write-Host "  Fetch the source page, then fetch same-domain links found on it; save only links matching *lha*:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://example.com`" `"*lha*`" `"matched.txt`" New -FollowDepth 1"
    Write-Host ""
    Write-Host "  Crawl two link hops, stay on the same exact host, and cap the crawl at 250 fetched pages:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://www.example.com`" `"*download*`" `"matched.txt`" New -FollowDepth 2 -FollowScope SameHost -MaxFollowPages 250"
    Write-Host ""
    Write-Host "  Crawl only inside the starting path/subtree. Example /1 allows /1/2 but not /2:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://example.com/1`" `"*news*story*`" `"matched.txt`" New -FollowDepth 10 -FollowScope SameDomain -FollowPathScope SeedPath"
    Write-Host ""
    Write-Host "  Crawl until the allowed frontier is exhausted; default MaxFollowPages is still 1000:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://example.com/1`" `"*news*story*`" `"matched.txt`" New -FollowUntilExhausted -FollowScope SameDomain -FollowPathScope SeedPath"
    Write-Host ""
    Write-Host "  Crawl same-domain direct subdomains too, but not deeper nested subdomains:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://example.com`" `"*zip*`" `"matched.txt`" New -FollowDepth 2 -FollowSubdomains:`$true -MaxSubdomainDepth 1"
    Write-Host ""
    Write-Host "  Crawl with opt-in robots.txt enforcement:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"https://example.com`" `"*lha*`" `"matched.txt`" New -FollowDepth 1 -EnforceRobotsTxt"
    Write-Host ""
    Write-Host "Examples -- blacklist:"
    Write-Host ""
    Write-Host "  Blacklist applied to both input and output (default):"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" `"*`" `"out.txt`" Append File -BlacklistFile `"blocked.txt`""
    Write-Host ""
    Write-Host "  Blacklist applied only to extracted output links:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" `"*`" `"out.txt`" Append File -BlacklistFile `"blocked.txt`" -BlacklistScope Output"
    Write-Host ""
    Write-Host "  Blacklist applied only to input URLs (skip fetching, keep in output):"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"urls.txt`" `"*`" `"out.txt`" Append File -BlacklistFile `"blocked.txt`" -BlacklistScope Input"
    Write-Host ""
    Write-Host "  Multiple blacklist files:"
    Write-Host "  .\AE-Find-WebLinks.ps1 `"bbc.co.uk`" `"*`" `"out.txt`" -BlacklistFile `"ads.txt`",`"tracking.txt`""
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
    Write-Host "Crawling behaviour:"
    Write-Host "  -FollowDepth controls which extracted links are fetched as additional pages."
    Write-Host "  0 means no crawling/default; -1, -FollowUntilExhausted, or -FollowToEnd crawls until"
    Write-Host "  no more allowed pages remain. MaxFollowPages is the crawl safety cap."
    Write-Host "  The search/exclude patterns only control what gets written to OutputFile."
    Write-Host "  Crawl candidates are followed by scope/depth rules even when they do not"
    Write-Host "  match the search pattern, otherwise crawler discovery becomes too narrow."
    Write-Host "  -FollowPathScope SeedPath adds a URL-subtree boundary on top of"
    Write-Host "  -FollowScope. For seed https://example.com/1, it allows /1 and"
    Write-Host "  /1/... but rejects /2 and /10. Query strings and fragments are"
    Write-Host "  ignored for this boundary."
    Write-Host "  SameDomain uses a built-in approximation of registrable domains. For exact"
    Write-Host "  eTLD+1 handling across every public/private suffix, use a Public Suffix List"
    Write-Host "  library in a larger crawler architecture."
    Write-Host "  robots.txt is not enforced unless -EnforceRobotsTxt is supplied. When enabled,"
    Write-Host "  source pages, crawl pages, and redirect targets are checked before fetching."
    Write-Host ""
    Write-Host "Note:"
    Write-Host "  This script downloads the raw HTTP response. It does NOT execute"
    Write-Host "  JavaScript, so content rendered entirely by client-side JS (React,"
    Write-Host "  Vue, Angular SPAs, etc.) will not be visible. It does extract URLs"
    Write-Host "  embedded in <script> blocks, JSON, CSS, and <noscript> fallbacks."
    Write-Host ""
    Write-Host "Security note:"
    Write-Host "  The script blocks private/internal source and redirect URLs as an SSRF"
    Write-Host "  guard, but DNS resolution is performed by the OS/.NET resolver. Broken"
    Write-Host "  or hostile DNS can still delay processing, and DNS rebinding cannot be"
    Write-Host "  fully eliminated in a standalone PowerShell HTTP client."
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Functions: Interactive CLI Builders
# Purpose: These handle user prompts when the script is run with -InteractiveHelp
#          They ensure strings are properly quoted and arrays are formatted.
# ---------------------------------------------------------------------------
function Format-PowerShellStringLiteral {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return "''" }

    $text = [string]$Value
    return "'" + $text.Replace("'", "''") + "'"
}

function Format-PowerShellArrayLiteral {
    param([AllowNull()][object[]]$Values)

    if ($null -eq $Values -or $Values.Count -eq 0) { return "@()" }

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($value in $Values) {
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            [void]$items.Add((Format-PowerShellStringLiteral $value))
        }
    }

    if ($items.Count -eq 0) { return "@()" }
    return ($items -join ",")
}

# The following Add-Command* functions build the argument strings piece by piece.
function Add-CommandValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Parts,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowNull()]
        [object]$Value,
        [switch]$Always
    )

    if (-not $Always) {
        if ($null -eq $Value) { return }
        if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) { return }
        if ($Value -is [array] -and $Value.Count -eq 0) { return }
    }

    [void]$Parts.Add("-$Name")

    if ($Value -is [array]) {
        [void]$Parts.Add((Format-PowerShellArrayLiteral ([object[]]$Value)))
    }
    else {
        [void]$Parts.Add((Format-PowerShellStringLiteral $Value))
    }
}

function Add-CommandIntValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Parts,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) { return }
    [void]$Parts.Add("-$Name")
    [void]$Parts.Add(([string]$Value))
}

function Add-CommandBoolValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Parts,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) { return }
    $boolText = if ([bool]$Value) { "true" } else { "false" }
    [void]$Parts.Add("-${Name}:`$$boolText")
}

function Add-CommandSwitch {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Parts,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowNull()]
        [object]$Enabled
    )

    if ($null -ne $Enabled -and [bool]$Enabled) {
        [void]$Parts.Add("-$Name")
    }
}

# The Read-Interactive* functions act as robust Wrappers around Read-Host,
# forcing correct user input types (Text, Int, Yes/No, Menus).
function Read-InteractiveText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [string]$Default = $null,
        [switch]$Required
    )

    while ($true) {
        $displayPrompt = $Prompt
        if (-not [string]::IsNullOrWhiteSpace($Default)) {
            $displayPrompt = "$Prompt [$Default]"
        }

        $value = Read-Host $displayPrompt

        if ([string]::IsNullOrWhiteSpace($value)) {
            if (-not [string]::IsNullOrWhiteSpace($Default)) {
                return $Default
            }

            if ($Required) {
                Write-Host "This value is required." -ForegroundColor Yellow
                continue
            }

            return $null
        }

        return $value.Trim()
    }
}

function Read-InteractiveInt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [AllowNull()]
        [object]$Default = $null,
        [int]$Minimum = 0,
        [int]$Maximum = 2147483647
    )

    while ($true) {
        $displayPrompt = $Prompt
        if ($null -ne $Default) {
            $displayPrompt = "$Prompt [$Default]"
        }

        $raw = Read-Host $displayPrompt
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Default
        }

        $parsed = 0
        if ([int]::TryParse($raw.Trim(), [ref]$parsed) -and $parsed -ge $Minimum -and $parsed -le $Maximum) {
            return $parsed
        }

        Write-Host "Enter a whole number between $Minimum and $Maximum." -ForegroundColor Yellow
    }
}

function Read-InteractiveYesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [bool]$Default = $false
    )

    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }

    while ($true) {
        $raw = Read-Host "$Prompt $suffix"

        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Default
        }

        switch -Regex ($raw.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$'  { return $false }
            default     { Write-Host "Please answer yes or no." -ForegroundColor Yellow }
        }
    }
}

function Read-InteractiveChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [Parameter(Mandatory = $true)]
        [string[]]$Choices,
        [int]$DefaultIndex = 0
    )

    if ($Choices.Count -eq 0) { throw "Read-InteractiveChoice requires at least one choice." }
    if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Choices.Count) {
        throw "Read-InteractiveChoice DefaultIndex $DefaultIndex is out of range for $($Choices.Count) choice(s)."
    }

    while ($true) {
        Write-Host ""
        Write-Host $Prompt
        for ($i = 0; $i -lt $Choices.Count; $i++) {
            $number = $i + 1
            $defaultMarker = if ($i -eq $DefaultIndex) { " [default]" } else { "" }
            Write-Host "  $number) $($Choices[$i])$defaultMarker"
        }

        $raw = Read-Host "Select an option"
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Choices[$DefaultIndex]
        }

        $selectedNumber = 0
        if ([int]::TryParse($raw.Trim(), [ref]$selectedNumber)) {
            if ($selectedNumber -ge 1 -and $selectedNumber -le $Choices.Count) {
                return $Choices[$selectedNumber - 1]
            }
        }

        foreach ($choice in $Choices) {
            if ($choice.Equals($raw.Trim(), [System.StringComparison]::OrdinalIgnoreCase)) {
                return $choice
            }
        }

        Write-Host "Invalid choice." -ForegroundColor Yellow
    }
}

function Convert-InteractiveList {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    return @(
        $Text -split ',' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

# The Set-Optional* functions write the acquired values directly into a Settings hashtable.
function Set-OptionalTextValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$Default = $null
    )

    $value = Read-InteractiveText -Prompt $Prompt -Default $Default
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $Settings[$Name] = $value
    }
}

function Set-OptionalIntValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [AllowNull()][object]$Default = $null,
        [int]$Minimum = 0,
        [int]$Maximum = 2147483647
    )

    $value = Read-InteractiveInt -Prompt $Prompt -Default $Default -Minimum $Minimum -Maximum $Maximum
    if ($null -ne $value) {
        $Settings[$Name] = $value
    }
}

function Set-OptionalChoiceValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string[]]$Choices,
        [int]$DefaultIndex = 0
    )

    $value = Read-InteractiveChoice -Prompt $Prompt -Choices $Choices -DefaultIndex $DefaultIndex
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $Settings[$Name] = $value
    }
}

function Set-OptionalBoolValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [bool]$Default = $false
    )

    $Settings[$Name] = (Read-InteractiveYesNo -Prompt $Prompt -Default $Default)
}

function Set-OptionalSwitchValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [bool]$Default = $false
    )

    $Settings[$Name] = (Read-InteractiveYesNo -Prompt $Prompt -Default $Default)
}

# ---------------------------------------------------------------------------
# Function: Edit-RunOptionalSettings
# Purpose: Navigates the interactive menus for advanced settings
# ---------------------------------------------------------------------------
function Edit-RunOptionalSettings {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string]$SourceType
    )

    while ($true) {
        $section = Read-InteractiveChoice `
            -Prompt "Optional settings. Pick a section, or finish." `
            -Choices @(
                "Finish and generate command",
                "Resume, blacklist, logging, and files",
                "Retry, network, proxy, and fetching",
                "Crawling and link-following",
                "Duplicates, sorting, and maintenance",
                "Limits, performance, and safety guardrails"
            ) `
            -DefaultIndex 0

        switch ($section) {
            "Finish and generate command" { return }

            "Resume, blacklist, logging, and files" {
                if ($SourceType -eq "File") {
                    Set-OptionalSwitchValue -Settings $Settings -Name "Resume" -Prompt "Is this a resume run from an existing progress file?" -Default $false
                    Set-OptionalTextValue -Settings $Settings -Name "ProgressFile" -Prompt "Custom progress file path? Leave blank for <OutputFile>.progress"
                }

                $blacklistText = Read-InteractiveText -Prompt "Blacklist file(s), comma-separated? Leave blank for none"
                $blacklist = @(Convert-InteractiveList $blacklistText)
                if ($blacklist.Count -gt 0) {
                    $Settings["BlacklistFile"] = $blacklist
                    Set-OptionalChoiceValue -Settings $Settings -Name "BlacklistScope" -Prompt "Where should the blacklist apply?" -Choices @("Both", "Input", "Output") -DefaultIndex 0
                }

                Set-OptionalTextValue -Settings $Settings -Name "LogCsv" -Prompt "CSV log file path? Leave blank for none"
                if ($Settings.ContainsKey("LogCsv")) {
                    Set-OptionalChoiceValue -Settings $Settings -Name "LogMode" -Prompt "CSV log mode?" -Choices @("Append", "New") -DefaultIndex 0
                }

                Set-OptionalTextValue -Settings $Settings -Name "FailedUrlFile" -Prompt "Failed URL file path? Leave blank for none"
                if ($Settings.ContainsKey("FailedUrlFile")) {
                    Set-OptionalChoiceValue -Settings $Settings -Name "FailedUrlMode" -Prompt "Failed URL file mode?" -Choices @("Append", "New") -DefaultIndex 0
                }

                Set-OptionalSwitchValue -Settings $Settings -Name "KeepFragments" -Prompt "Keep URL fragments (#...) when deduplicating?" -Default $false

                $stripEvaluationRegex = Read-InteractiveYesNo -Prompt "Strip a regex-matched part from extracted links before matching/output/deduplication?" -Default $false
                if ($stripEvaluationRegex) {
                    $Settings["StripRegexBeforeEvaluation"] = $true
                    $stripRegexValue = Read-InteractiveText -Prompt "Regex to remove from links before evaluation. Example: /\d+$" -Required
                    $Settings["LinkEvaluationStripRegex"] = $stripRegexValue
                }
            }

            "Retry, network, proxy, and fetching" {
                Set-OptionalIntValue -Settings $Settings -Name "RetryCount" -Prompt "Retry attempts per URL" -Default 3 -Minimum 1
                Set-OptionalIntValue -Settings $Settings -Name "WaitSeconds" -Prompt "Seconds between retries" -Default 30
                Set-OptionalIntValue -Settings $Settings -Name "TimeoutSeconds" -Prompt "HTTP timeout per attempt, seconds" -Default 120 -Minimum 1
                if ($SourceType -eq "File") {
                    Set-OptionalIntValue -Settings $Settings -Name "DelaySeconds" -Prompt "Seconds between different source URLs" -Default 5
                    Set-OptionalIntValue -Settings $Settings -Name "ThrottleLimit" -Prompt "Parallel source URLs. 1 = sequential. PS 7+ required above 1" -Default 1 -Minimum 1
                }
                Set-OptionalBoolValue -Settings $Settings -Name "SecondFetch" -Prompt "Fetch each URL twice and keep the larger response?" -Default $true
                if ($Settings.ContainsKey("SecondFetch") -and [bool]$Settings["SecondFetch"]) {
                    Set-OptionalIntValue -Settings $Settings -Name "SecondFetchWait" -Prompt "Seconds before the second fetch" -Default 5
                }
                Set-OptionalTextValue -Settings $Settings -Name "Proxy" -Prompt "Proxy URL? Example: http://proxy:8080. Leave blank for none"
                Set-OptionalTextValue -Settings $Settings -Name "UserAgent" -Prompt "Custom User-Agent? Leave blank for default"
                Set-OptionalSwitchValue -Settings $Settings -Name "EnforceRobotsTxt" -Prompt "Enforce robots.txt before fetching URLs and redirects?" -Default $false
                if ($Settings.ContainsKey("EnforceRobotsTxt") -and [bool]$Settings["EnforceRobotsTxt"]) {
                    Set-OptionalTextValue -Settings $Settings -Name "RobotsUserAgent" -Prompt "robots.txt User-agent product token" -Default "AE-Find-WebLinks"
                }
                Set-OptionalIntValue -Settings $Settings -Name "MaxRedirects" -Prompt "Maximum HTTP/meta-refresh redirects" -Default 10 -Minimum 1
                Set-OptionalIntValue -Settings $Settings -Name "MaxRetryAfterSeconds" -Prompt "Maximum server Retry-After seconds to honour. 0 = ignore" -Default 300
                Set-OptionalIntValue -Settings $Settings -Name "ConnectionLimit" -Prompt ".NET HTTP connection limit" -Default 100 -Minimum 1
            }

            "Crawling and link-following" {
                Set-OptionalSwitchValue -Settings $Settings -Name "FollowUntilExhausted" -Prompt "Crawl until no new allowed pages remain?" -Default $false
                if (-not ($Settings.ContainsKey("FollowUntilExhausted") -and [bool]$Settings["FollowUntilExhausted"])) {
                    Set-OptionalIntValue -Settings $Settings -Name "FollowDepth" -Prompt "Link-hop depth to follow. 0 = source page(s) only/no crawl; -1 = until exhausted" -Default 0 -Minimum -1
                }

                $crawlRequested = $false
                if ($Settings.ContainsKey("FollowUntilExhausted") -and [bool]$Settings["FollowUntilExhausted"]) { $crawlRequested = $true }
                if ($Settings.ContainsKey("FollowDepth") -and [int]$Settings["FollowDepth"] -ne 0) { $crawlRequested = $true }

                if ($crawlRequested) {
                    Set-OptionalChoiceValue -Settings $Settings -Name "FollowScope" -Prompt "Which host/domain links may be followed?" -Choices @("SameDomain", "SameHost", "Any") -DefaultIndex 0
                    Set-OptionalChoiceValue -Settings $Settings -Name "FollowPathScope" -Prompt "Restrict crawling to the starting URL path/subtree?" -Choices @("Any", "SeedPath") -DefaultIndex 0
                    if (-not $Settings.ContainsKey("DelaySeconds")) {
                        Set-OptionalIntValue -Settings $Settings -Name "DelaySeconds" -Prompt "Seconds between crawled URLs" -Default 5
                    }
                    Set-OptionalBoolValue -Settings $Settings -Name "FollowSubdomains" -Prompt "In SameDomain mode, follow non-seed subdomains?" -Default $false
                    if ($Settings.ContainsKey("FollowSubdomains") -and [bool]$Settings["FollowSubdomains"]) {
                        Set-OptionalIntValue -Settings $Settings -Name "MaxSubdomainDepth" -Prompt "Maximum subdomain depth. 1 = direct subdomains, 0 = no limit" -Default 1
                    }
                    Set-OptionalIntValue -Settings $Settings -Name "MaxFollowPages" -Prompt "Maximum pages to fetch during crawl. 0 = no cap" -Default 1000
                }
            }

            "Duplicates, sorting, and maintenance" {
                Set-OptionalBoolValue -Settings $Settings -Name "NoDuplicates" -Prompt "Skip links already written or already present in the output file?" -Default $true
                Set-OptionalSwitchValue -Settings $Settings -Name "KeepDuplicates" -Prompt "Keep repeated matches found inside the same page?" -Default $false
                Set-OptionalChoiceValue -Settings $Settings -Name "DeduplicateWhen" -Prompt "Deduplicate involved files when?" -Choices @("None", "Start", "End", "Both") -DefaultIndex 0
                Set-OptionalChoiceValue -Settings $Settings -Name "SortWhen" -Prompt "Sort involved files when?" -Choices @("None", "Start", "End", "Both") -DefaultIndex 0
                if ($Settings.ContainsKey("SortWhen") -and $Settings["SortWhen"] -ne "None") {
                    Set-OptionalChoiceValue -Settings $Settings -Name "SortDirection" -Prompt "Sort direction?" -Choices @("Ascending", "Descending") -DefaultIndex 0
                }
                Set-OptionalSwitchValue -Settings $Settings -Name "DeduplicateFiles" -Prompt "Use legacy -DeduplicateFiles switch before starting? Usually leave this off." -Default $false
                Set-OptionalBoolValue -Settings $Settings -Name "SortOutput" -Prompt "Use legacy -SortOutput after the run? Usually prefer -SortWhen End." -Default $false
            }

            "Limits, performance, and safety guardrails" {
                Set-OptionalIntValue -Settings $Settings -Name "MaintenanceLargeFileLimitMB" -Prompt "Max MB for in-memory dedup/sort. 0 = no limit" -Default 1024
                Set-OptionalSwitchValue -Settings $Settings -Name "IgnoreMaintenanceLargeFileLimit" -Prompt "Ignore the maintenance large-file limit?" -Default $false
                Set-OptionalIntValue -Settings $Settings -Name "MaxPageContentMB" -Prompt "Max page body size to parse, MB. 0 = no limit" -Default 50
                Set-OptionalIntValue -Settings $Settings -Name "RegexTimeoutSeconds" -Prompt "Regex timeout seconds. 0 = no timeout" -Default 10
                Set-OptionalIntValue -Settings $Settings -Name "MaxUrlLength" -Prompt "Max extracted URL length before skipping. 0 = no limit" -Default 8192
                Set-OptionalIntValue -Settings $Settings -Name "FileWriteRetryCount" -Prompt "Output/log/progress append retry attempts" -Default 5 -Minimum 1
                Set-OptionalIntValue -Settings $Settings -Name "FileWriteRetryDelayMinMs" -Prompt "Minimum append retry delay, ms" -Default 50
                Set-OptionalIntValue -Settings $Settings -Name "FileWriteRetryDelayMaxMs" -Prompt "Maximum append retry delay, ms" -Default 300
                Set-OptionalIntValue -Settings $Settings -Name "FileMoveRetryCount" -Prompt "Dedup/sort replace retry attempts" -Default 5 -Minimum 1
                Set-OptionalIntValue -Settings $Settings -Name "FileMoveRetryDelayMs" -Prompt "Delay between dedup/sort replace retries, ms" -Default 300
                Set-OptionalIntValue -Settings $Settings -Name "HighFailureRatePercent" -Prompt "Warn when File-mode failures reach this percent. 0 = disable" -Default 50 -Minimum 0 -Maximum 100
                Set-OptionalSwitchValue -Settings $Settings -Name "AllowExtremeOperationalValues" -Prompt "Allow values above normal typo guardrails?" -Default $false
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Functions: Command string generators (Interactive Mode)
# Purpose: Compiles all the collected interactive answers into a final
#          copy-pasteable PowerShell command line.
# ---------------------------------------------------------------------------
function New-RunCommandFromInteractiveAnswers {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string[]]$SearchPatternsValue,
        [Parameter(Mandatory = $true)][string]$SearchModeValue,
        [AllowNull()][string[]]$ExcludePatternsValue,
        [AllowNull()][string]$ExcludeModeValue,
        [Parameter(Mandatory = $true)][string]$OutputFileValue,
        [Parameter(Mandatory = $true)][string]$ModeValue,
        [Parameter(Mandatory = $true)][string]$SourceTypeValue,
        [Parameter(Mandatory = $true)][hashtable]$Settings
    )

    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add(".\AE-Find-WebLinks.ps1")

    Add-CommandValue -Parts $parts -Name "Source" -Value $Source -Always

    if ($SearchPatternsValue.Count -eq 1) {
        Add-CommandValue -Parts $parts -Name "SearchPattern" -Value $SearchPatternsValue[0] -Always
    }
    else {
        Add-CommandValue -Parts $parts -Name "SearchPatterns" -Value $SearchPatternsValue -Always
    }

    if ($SearchPatternsValue.Count -gt 1 -or $SearchModeValue -ne "Any") {
        Add-CommandValue -Parts $parts -Name "SearchMode" -Value $SearchModeValue
    }

    if ($ExcludePatternsValue -and $ExcludePatternsValue.Count -gt 0) {
        if ($ExcludePatternsValue.Count -eq 1) {
            Add-CommandValue -Parts $parts -Name "ExcludePattern" -Value $ExcludePatternsValue[0]
        }
        else {
            Add-CommandValue -Parts $parts -Name "ExcludePatterns" -Value $ExcludePatternsValue
        }
        Add-CommandValue -Parts $parts -Name "ExcludeMode" -Value $ExcludeModeValue
    }

    Add-CommandValue -Parts $parts -Name "OutputFile" -Value $OutputFileValue -Always
    Add-CommandValue -Parts $parts -Name "Mode" -Value $ModeValue -Always
    Add-CommandValue -Parts $parts -Name "SourceType" -Value $SourceTypeValue -Always

    # Append standard string settings
    foreach ($name in @(
        "BlacklistScope", "FollowScope", "FollowPathScope", "LogMode", "FailedUrlMode", "SortDirection", "DeduplicateWhen", "SortWhen",
        "Proxy", "UserAgent", "RobotsUserAgent", "ProgressFile", "LogCsv", "FailedUrlFile", "LinkEvaluationStripRegex"
    )) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandValue -Parts $parts -Name $name -Value $Settings[$name]
        }
    }

    # Append list settings
    foreach ($name in @("BlacklistFile")) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandValue -Parts $parts -Name $name -Value $Settings[$name]
        }
    }

    # Append Integer settings
    foreach ($name in @(
        "RetryCount", "WaitSeconds", "TimeoutSeconds", "DelaySeconds", "FollowDepth", "MaxSubdomainDepth", "MaxFollowPages",
        "SecondFetchWait", "ThrottleLimit", "MaxRedirects", "MaxRetryAfterSeconds", "ConnectionLimit", "MaintenanceLargeFileLimitMB",
        "MaxPageContentMB", "RegexTimeoutSeconds", "MaxUrlLength", "FileWriteRetryCount",
        "FileWriteRetryDelayMinMs", "FileWriteRetryDelayMaxMs", "FileMoveRetryCount", "FileMoveRetryDelayMs",
        "HighFailureRatePercent"
    )) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandIntValue -Parts $parts -Name $name -Value $Settings[$name]
        }
    }

    # Append boolean settings
    foreach ($name in @("SecondFetch", "FollowSubdomains", "NoDuplicates", "SortOutput")) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandBoolValue -Parts $parts -Name $name -Value $Settings[$name]
        }
    }

    # Append Switch settings
    foreach ($name in @(
        "Resume", "KeepDuplicates", "DeduplicateFiles", "KeepFragments", "StripRegexBeforeEvaluation", "EnforceRobotsTxt", "FollowUntilExhausted",
        "IgnoreMaintenanceLargeFileLimit", "AllowExtremeOperationalValues"
    )) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandSwitch -Parts $parts -Name $name -Enabled $Settings[$name]
        }
    }

    return ($parts -join " ")
}

function Start-InteractiveRunCommandBuilder {
    Write-Host ""
    Write-Host "Interactive run command builder"
    Write-Host "This will only build a command string. It will not fetch URLs or write files."

    $sourceTypeChoice = Read-InteractiveChoice -Prompt "What do you want to process?" -Choices @("One web page URL", "A text file containing many source URLs") -DefaultIndex 1
    $sourceTypeValue = if ($sourceTypeChoice -eq "One web page URL") { "Url" } else { "File" }

    $sourcePrompt = if ($sourceTypeValue -eq "Url") { "Source URL" } else { "Source text file containing URLs" }
    $sourceValue = Read-InteractiveText -Prompt $sourcePrompt -Required

    $patternText = Read-InteractiveText -Prompt "Search pattern(s), comma-separated. Use wildcards like *zip* or press Enter for all links" -Default "*"
    $searchPatternsValue = @(Convert-InteractiveList $patternText)
    if ($searchPatternsValue.Count -eq 0) { $searchPatternsValue = @("*") }

    $searchModeValue = "Any"
    if ($searchPatternsValue.Count -gt 1) {
        $searchModeValue = Read-InteractiveChoice -Prompt "How should multiple search patterns match?" -Choices @("Any", "All") -DefaultIndex 0
    }

    $excludePatternsValue = @()
    $excludeModeValue = "Any"
    if (Read-InteractiveYesNo -Prompt "Do you want to exclude matching links with wildcard patterns?" -Default $false) {
        $excludeText = Read-InteractiveText -Prompt "Exclude pattern(s), comma-separated. Example: *demo*,*trailer*" -Required
        $excludePatternsValue = @(Convert-InteractiveList $excludeText)
        if ($excludePatternsValue.Count -gt 1) {
            $excludeModeValue = Read-InteractiveChoice -Prompt "How should multiple exclude patterns work?" -Choices @("Any", "All") -DefaultIndex 0
        }
    }

    $outputFileValue = Read-InteractiveText -Prompt "Output file for matched links" -Default ".\matched-links.txt" -Required
    $modeValue = Read-InteractiveChoice -Prompt "Output mode?" -Choices @("Append", "New") -DefaultIndex 0

    $settings = @{}

    if (Read-InteractiveYesNo -Prompt "Do you want to review optional settings?" -Default $false) {
        Edit-RunOptionalSettings -Settings $settings -SourceType $sourceTypeValue
    }

    $commandLine = New-RunCommandFromInteractiveAnswers `
        -Source $sourceValue `
        -SearchPatternsValue $searchPatternsValue `
        -SearchModeValue $searchModeValue `
        -ExcludePatternsValue $excludePatternsValue `
        -ExcludeModeValue $excludeModeValue `
        -OutputFileValue $outputFileValue `
        -ModeValue $modeValue `
        -SourceTypeValue $sourceTypeValue `
        -Settings $settings

    Write-Host ""
    Write-Host "Generated command:" -ForegroundColor Green
    Write-Host ""
    Write-Host $commandLine -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Nothing was executed. Copy and run the command above when ready."
}

function New-MaintenanceCommandFromInteractiveAnswers {
    param(
        [Parameter(Mandatory = $true)][string]$CommandValue,
        [Parameter(Mandatory = $true)][string[]]$FilesValue,
        [Parameter(Mandatory = $true)][hashtable]$Settings
    )

    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add(".\AE-Find-WebLinks.ps1")

    Add-CommandValue -Parts $parts -Name "Command" -Value $CommandValue -Always
    Add-CommandValue -Parts $parts -Name "Files" -Value $FilesValue -Always

    foreach ($name in @("SortDirection", "DeduplicateWhen", "SortWhen")) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandValue -Parts $parts -Name $name -Value $Settings[$name]
        }
    }

    foreach ($name in @(
        "MaintenanceLargeFileLimitMB", "FileMoveRetryCount", "FileMoveRetryDelayMs",
        "FileWriteRetryCount", "FileWriteRetryDelayMinMs", "FileWriteRetryDelayMaxMs"
    )) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandIntValue -Parts $parts -Name $name -Value $Settings[$name]
        }
    }

    foreach ($name in @("IgnoreMaintenanceLargeFileLimit", "AllowExtremeOperationalValues", "KeepFragments")) {
        if ($Settings.ContainsKey($name)) {
            Add-CommandSwitch -Parts $parts -Name $name -Enabled $Settings[$name]
        }
    }

    return ($parts -join " ")
}

function Start-InteractiveMaintenanceCommandBuilder {
    Write-Host ""
    Write-Host "Interactive maintenance command builder"
    Write-Host "This will only build a command string. It will not modify files."

    $commandValue = Read-InteractiveChoice -Prompt "What maintenance command do you want?" -Choices @("Deduplicate", "Sort", "Maintain") -DefaultIndex 0

    $filesText = Read-InteractiveText -Prompt "File(s) to maintain, comma-separated" -Required
    $filesValue = @(Convert-InteractiveList $filesText)
    while ($filesValue.Count -eq 0) {
        Write-Host "At least one file is required." -ForegroundColor Yellow
        $filesText = Read-InteractiveText -Prompt "File(s) to maintain, comma-separated" -Required
        $filesValue = @(Convert-InteractiveList $filesText)
    }

    $settings = @{}

    if ($commandValue -eq "Sort") {
        Set-OptionalChoiceValue -Settings $settings -Name "SortDirection" -Prompt "Sort direction?" -Choices @("Ascending", "Descending") -DefaultIndex 0
    }
    elseif ($commandValue -eq "Maintain") {
        Set-OptionalChoiceValue -Settings $settings -Name "DeduplicateWhen" -Prompt "Deduplicate when? In standalone maintenance, Start/End/Both collapse to one pass." -Choices @("None", "Start", "End", "Both") -DefaultIndex 1
        Set-OptionalChoiceValue -Settings $settings -Name "SortWhen" -Prompt "Sort when? In standalone maintenance, Start/End/Both collapse to one pass." -Choices @("None", "Start", "End", "Both") -DefaultIndex 0
        if ($settings.ContainsKey("SortWhen") -and $settings["SortWhen"] -ne "None") {
            Set-OptionalChoiceValue -Settings $settings -Name "SortDirection" -Prompt "Sort direction?" -Choices @("Ascending", "Descending") -DefaultIndex 0
        }
    }

    if (Read-InteractiveYesNo -Prompt "Review advanced maintenance and file safety options?" -Default $false) {
        if ($commandValue -eq "Deduplicate" -or ($commandValue -eq "Maintain" -and $settings.ContainsKey("DeduplicateWhen") -and $settings["DeduplicateWhen"] -ne "None")) {
            Set-OptionalSwitchValue -Settings $settings -Name "KeepFragments" -Prompt "Keep URL fragments (#...) when deduplicating?" -Default $false
        }
        Set-OptionalIntValue -Settings $settings -Name "MaintenanceLargeFileLimitMB" -Prompt "Max MB for in-memory dedup/sort. 0 = no limit" -Default 1024
        Set-OptionalSwitchValue -Settings $settings -Name "IgnoreMaintenanceLargeFileLimit" -Prompt "Ignore the maintenance large-file limit?" -Default $false
        Set-OptionalIntValue -Settings $settings -Name "FileWriteRetryCount" -Prompt "Temp/output write retry attempts" -Default 5 -Minimum 1
        Set-OptionalIntValue -Settings $settings -Name "FileWriteRetryDelayMinMs" -Prompt "Minimum write retry delay, ms" -Default 50
        Set-OptionalIntValue -Settings $settings -Name "FileWriteRetryDelayMaxMs" -Prompt "Maximum write retry delay, ms" -Default 300
        Set-OptionalIntValue -Settings $settings -Name "FileMoveRetryCount" -Prompt "Replace retry attempts" -Default 5 -Minimum 1
        Set-OptionalIntValue -Settings $settings -Name "FileMoveRetryDelayMs" -Prompt "Replace retry delay, ms" -Default 300
        Set-OptionalSwitchValue -Settings $settings -Name "AllowExtremeOperationalValues" -Prompt "Allow values above normal typo guardrails?" -Default $false
    }

    $commandLine = New-MaintenanceCommandFromInteractiveAnswers -CommandValue $commandValue -FilesValue $filesValue -Settings $settings

    Write-Host ""
    Write-Host "Generated command:" -ForegroundColor Green
    Write-Host ""
    Write-Host $commandLine -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Nothing was executed. Copy and run the command above when ready."
}

function Start-InteractiveHelp {
    Write-Host ""
    Write-Host "AE-Find-WebLinks guided helper"
    Write-Host "It asks questions and prints the command to run. It does not run the command."

    $modeChoice = Read-InteractiveChoice -Prompt "What do you want help building?" -Choices @("Run / scrape links", "Maintenance only") -DefaultIndex 0

    if ($modeChoice -eq "Maintenance only") {
        Start-InteractiveMaintenanceCommandBuilder
    }
    else {
        Start-InteractiveRunCommandBuilder
    }
}

# ==============================================================================
# SCRIPT ENTRY GATES
# Checks if we should exit early to display help rather than running the engine
# ==============================================================================

if ($Help) {
    Show-Usage
    exit 0
}

if ($InteractiveHelp) {
    Start-InteractiveHelp
    exit 0
}

if ($PSBoundParameters.Count -eq 0) {
    Write-Host ""
    Write-Host "AE-Find-WebLinks was started without parameters."
    $startupChoice = Read-InteractiveChoice -Prompt "What do you want to do?" -Choices @("Show help", "Interactive command builder", "Exit") -DefaultIndex 1

    switch ($startupChoice) {
        "Show help" {
            Show-Usage
            exit 0
        }
        "Interactive command builder" {
            Start-InteractiveHelp
            exit 0
        }
        "Exit" {
            Write-Host "No command was run."
            exit 0
        }
    }
}

# Ensure required parameters are provided if we are doing a real run
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
# CORE HELPERS
# Path resolution, object disposal, and error identification
# ---------------------------------------------------------------------------

# Helper: Converts a relative path into an absolute file path robustly
function Get-SafeAbsolutePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $unresolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [System.IO.Path]::GetFullPath($unresolved)
}

# Helper: Disposes of WebRequest objects so memory leaks don't happen
function Close-BaseResponseSafe {
    param([AllowNull()][object]$Response)

    if ($null -eq $Response) { return }

    # Capture nested response objects before disposing the wrapper. Some PowerShell
    # web response wrappers throw "Operation is not valid due to the current state
    # of the object" if BaseResponse is inspected after disposal or cancellation.
    $baseResponse = $null
    try {
        $brProp = $Response.PSObject.Properties['BaseResponse']
        if ($null -ne $brProp -and $null -ne $brProp.Value) {
            $baseResponse = $brProp.Value
        }
    }
    catch { }

    try {
        if ($Response -is [System.IDisposable]) {
            $Response.Dispose()
        }
    }
    catch {
        # Never allow cleanup/disposal to mask the real network error.
    }

    try {
        if (
            $null -ne $baseResponse -and
            $baseResponse -is [System.IDisposable] -and
            -not [object]::ReferenceEquals($baseResponse, $Response)
        ) {
            $baseResponse.Dispose()
        }
    }
    catch {
        # Never allow cleanup/disposal to mask the real network error.
    }
}

# Helper: Identifies if a task was manually cancelled (e.g., Ctrl+C)
function Test-IsCancellationException {
    param([AllowNull()][object]$ErrorObject)

    if ($null -eq $ErrorObject) { return $false }

    $ex = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        $ErrorObject.Exception
    }
    elseif ($ErrorObject.PSObject.Properties['Exception']) {
        $ErrorObject.Exception
    }
    else {
        $ErrorObject
    }

    while ($null -ne $ex) {
        $typeName = $ex.GetType().FullName

        if (
            $ex -is [System.Management.Automation.PipelineStoppedException] -or
            $ex -is [System.OperationCanceledException] -or
            $typeName -eq 'System.Threading.Tasks.TaskCanceledException' -or
            $typeName -eq 'System.Threading.ThreadInterruptedException' -or
            $typeName -eq 'System.Threading.ThreadAbortException'
        ) {
            return $true
        }

        $ex = $ex.InnerException
    }

    return $false
}

# Helper: Detects internal PowerShell Invoke-WebRequest state crashes
function Test-IsInvalidWebRequestStateError {
    param([AllowNull()][object]$ErrorObject)

    if ($null -eq $ErrorObject) { return $false }

    $ex = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        $ErrorObject.Exception
    }
    elseif ($ErrorObject.PSObject.Properties['Exception']) {
        $ErrorObject.Exception
    }
    else {
        $ErrorObject
    }

    while ($null -ne $ex) {
        if (
            $ex -is [System.InvalidOperationException] -and
            $ex.Message -match 'current state of the object'
        ) {
            return $true
        }

        $ex = $ex.InnerException
    }

    return $false
}

# ---------------------------------------------------------------------------
# PATTERN MATCHING & URL NORMALIZATION HELPERS
# ---------------------------------------------------------------------------

# Helper: Translates simple wildcard strings like "*sport*" to robust Regex "^.*sport.*$"
function Convert-WildcardToRegex {
    param([string]$Pattern)

    $escaped = [regex]::Escape($Pattern)
    $regex   = $escaped -replace '\\\*', '.*' -replace '\\\?', '.'
    return "^$regex$"
}

function Get-LinkEvaluationValue {
    param([AllowNull()][string]$Link)

    if ([string]::IsNullOrWhiteSpace($Link)) { return $Link }
    if (-not $Script:StripRegexBeforeEvaluation -or $null -eq $Script:LinkEvaluationStripRegexObject) { return $Link }

    $candidate = $Link.Trim()

    try {
        $candidate = $Script:LinkEvaluationStripRegexObject.Replace($candidate, "")
    }
    catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
        if (-not $Script:LinkEvaluationStripRegexWarned) {
            Write-Host "  WARNING: Link evaluation strip regex timed out; continuing with original link values."
            $Script:LinkEvaluationStripRegexWarned = $true
        }
        return $Link
    }

    if ([string]::IsNullOrWhiteSpace($candidate)) { return $Link }

    # If the stripped value is still a valid URL, return its normalized form so
    # matching/dedup/output compare a stable URL. If the user's regex produces a
    # non-URL string, still return the stripped text for wildcard matching.
    try {
        $normalized = ConvertTo-NormalizedLink -Link $candidate
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            return $normalized
        }
    }
    catch {
        # Fall back to the stripped string below.
    }

    return $candidate.Trim()
}

function Get-EffectiveSearchPatterns {
    param(
        [AllowNull()]
        [string]$MainPattern,

        [AllowNull()]
        [string[]]$PatternList
    )

    $patterns = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($MainPattern)) {
        [void]$patterns.Add($MainPattern.Trim())
    }

    if ($PatternList) {
        foreach ($pattern in $PatternList) {
            if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                [void]$patterns.Add($pattern.Trim())
            }
        }
    }

    return @($patterns | Select-Object -Unique)
}

function Get-EffectiveExcludePatterns {
    param(
        [AllowNull()]
        [string]$MainPattern,

        [AllowNull()]
        [string[]]$PatternList
    )

    $patterns = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($MainPattern)) {
        [void]$patterns.Add($MainPattern.Trim())
    }

    if ($PatternList) {
        foreach ($pattern in $PatternList) {
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
        [string]$Mode,
        [bool]$UseEvaluationValue = $false
    )

    if ([string]::IsNullOrWhiteSpace($Link)) { return $false }

    $linkToEvaluate = if ($UseEvaluationValue) { Get-LinkEvaluationValue -Link $Link } else { $Link }
    if ([string]::IsNullOrWhiteSpace($linkToEvaluate)) { return $false }

    if ($Mode -eq "All") {
        foreach ($regex in $RegexList) {
            if ($linkToEvaluate -notmatch $regex) {
                return $false
            }
        }
        return $true
    }

    foreach ($regex in $RegexList) {
        if ($linkToEvaluate -match $regex) {
            return $true
        }
    }

    return $false
}

function Test-LinkMatchesExclude {
    param(
        [string]$Link,
        [string[]]$RegexList,
        [string]$Mode,
        [bool]$UseEvaluationValue = $false
    )

    if ($null -eq $RegexList -or $RegexList.Count -eq 0) { return $false }
    return (Test-LinkMatchesSearch -Link $Link -RegexList $RegexList -Mode $Mode -UseEvaluationValue $UseEvaluationValue)
}

# ---------------------------------------------------------------------------
# Function: Get-LinkKey
# Purpose: Normalises a link for "same enough" duplicate comparison.
#          Strips fragments (#...) unless told otherwise, removes HTTP/HTTPS 
#          protocols so mixed-scheme URLs match, trims slashes, and lowercases.
# ---------------------------------------------------------------------------
function Get-LinkKey {
    param(
        [string]$Link,
        [bool]$KeepFragments = $false,
        [bool]$UseEvaluationValue = $false
    )

    if ([string]::IsNullOrWhiteSpace($Link)) { return "" }

    if ($UseEvaluationValue) {
        $evaluatedLink = Get-LinkEvaluationValue -Link $Link
        if (-not [string]::IsNullOrWhiteSpace($evaluatedLink)) {
            $Link = $evaluatedLink
        }
    }

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

# Helper: Formats the final URL string as it should appear written in the output text file
function Get-LinkWriteValue {
    param(
        [string]$Link,
        [bool]$KeepFragments = $false,
        [bool]$UseEvaluationValue = $false
    )

    if ([string]::IsNullOrWhiteSpace($Link)) { return "" }

    if ($UseEvaluationValue) {
        $evaluatedLink = Get-LinkEvaluationValue -Link $Link
        if (-not [string]::IsNullOrWhiteSpace($evaluatedLink)) {
            $Link = $evaluatedLink
        }
    }

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


# ---------------------------------------------------------------------------
# Crawl boundary helpers
# ---------------------------------------------------------------------------
# Standard crawler implementations normally use the Public Suffix List (PSL) to
# calculate the registrable domain/eTLD+1. Example: www.example.co.uk belongs to
# example.co.uk, not co.uk. This standalone script avoids network/package
# dependencies, so Get-RegistrableDomain uses a conservative built-in heuristic:
# last two labels normally, or last three labels for common ccTLD second-level
# suffixes such as co.uk/com.au. This is good enough for ordinary sites, but it
# is not a full PSL replacement and cannot know private suffixes such as
# github.io, appspot.com, or blogspot.com. Use -FollowScope SameHost when you
# need the safest possible boundary, or integrate a PSL library for exact logic.
function Get-UrlHost {
    param([AllowNull()][string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }

    try {
        $uri = [uri]$Url
        if ($uri.IsAbsoluteUri -and $uri.Scheme -match '^https?$' -and -not [string]::IsNullOrWhiteSpace($uri.Host)) {
            return $uri.Host.TrimEnd('.').ToLowerInvariant()
        }
    }
    catch { }

    return $null
}

function Test-HostIsIPAddress {
    param([AllowNull()][string]$HostName)

    if ([string]::IsNullOrWhiteSpace($HostName)) { return $false }

    $ip = $null
    return [System.Net.IPAddress]::TryParse($HostName.Trim('[', ']', ' '), [ref]$ip)
}

function Get-RegistrableDomain {
    param([AllowNull()][string]$HostName)

    if ([string]::IsNullOrWhiteSpace($HostName)) { return $null }

    $cleanHost = $HostName.Trim().TrimEnd('.').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($cleanHost)) { return $null }
    if (Test-HostIsIPAddress -HostName $cleanHost) { return $cleanHost }

    $labels = @($cleanHost -split '\.' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($labels.Count -le 2) { return ($labels -join '.') }

    $tld = $labels[$labels.Count - 1]
    $sld = $labels[$labels.Count - 2]

    # Common public second-level labels under ccTLDs. This deliberately remains
    # small and generic; it prevents dangerous broad matches like co.uk while
    # avoiding a pretend full PSL implementation.
    $commonCcSecondLevelLabels = @(
        'ac','co','com','edu','gov','net','org','mil','mod','nhs','nic','nom','plc','police','sch',
        'asso','gob','go','or','ne','re','id','web','gen','firm','store','arts','rec','info'
    )

    if ($tld.Length -eq 2 -and $commonCcSecondLevelLabels -contains $sld -and $labels.Count -ge 3) {
        return ($labels[($labels.Count - 3)..($labels.Count - 1)] -join '.')
    }

    return ($labels[($labels.Count - 2)..($labels.Count - 1)] -join '.')
}

function Get-SubdomainDepthForRoot {
    param(
        [AllowNull()][string]$HostName,
        [AllowNull()][string]$RootDomain
    )

    if ([string]::IsNullOrWhiteSpace($HostName) -or [string]::IsNullOrWhiteSpace($RootDomain)) { return -1 }

    $hostClean = $HostName.Trim().TrimEnd('.').ToLowerInvariant()
    $rootClean = $RootDomain.Trim().TrimEnd('.').ToLowerInvariant()

    if ($hostClean -ieq $rootClean) { return 0 }
    if (-not $hostClean.EndsWith(".$rootClean", [System.StringComparison]::OrdinalIgnoreCase)) { return -1 }

    $prefixLength = $hostClean.Length - $rootClean.Length - 1
    if ($prefixLength -le 0) { return 0 }

    $prefix = $hostClean.Substring(0, $prefixLength)
    if ([string]::IsNullOrWhiteSpace($prefix)) { return 0 }

    return @($prefix -split '\.' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

function Get-UrlPathPrefix {
    param([AllowNull()][string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }

    try {
        $normalizedUrl = ConvertTo-NormalizedLink -Link $Url
        if (-not $normalizedUrl) { return $null }

        $uri = [uri]$normalizedUrl
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notmatch '^https?$') { return $null }

        # AbsolutePath excludes query and fragment. This is intentional: /1?a=b
        # and /1#top are still inside the /1 path boundary.
        $path = $uri.AbsolutePath
        if ([string]::IsNullOrWhiteSpace($path)) { return "/" }
        if (-not $path.StartsWith("/")) { $path = "/$path" }

        # Treat /1 and /1/ as the same subtree root. Root remains root.
        if ($path.Length -gt 1) {
            $path = $path.TrimEnd('/')
            if ([string]::IsNullOrWhiteSpace($path)) { return "/" }
        }

        return $path
    }
    catch {
        return $null
    }
}

function Test-UrlPathUnderPrefix {
    param(
        [AllowNull()][string]$Url,
        [AllowNull()][string]$PathPrefix
    )

    if ([string]::IsNullOrWhiteSpace($Url) -or [string]::IsNullOrWhiteSpace($PathPrefix)) { return $false }

    $prefix = $PathPrefix
    if (-not $prefix.StartsWith("/")) { $prefix = "/$prefix" }
    if ($prefix.Length -gt 1) { $prefix = $prefix.TrimEnd('/') }
    if ([string]::IsNullOrWhiteSpace($prefix) -or $prefix -eq "/") { return $true }

    $candidatePath = Get-UrlPathPrefix -Url $Url
    if ([string]::IsNullOrWhiteSpace($candidatePath)) { return $false }

    # URL paths are case-sensitive on many servers. Use Ordinal rather than
    # OrdinalIgnoreCase so /Games and /games do not get silently collapsed.
    if ([string]::Equals($candidatePath, $prefix, [System.StringComparison]::Ordinal)) { return $true }
    return $candidatePath.StartsWith("$prefix/", [System.StringComparison]::Ordinal)
}

function New-FollowBoundary {
    param(
        [AllowNull()][string[]]$SeedUrls,
        [bool]$UseEvaluationValue = $false
    )

    $hosts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $domains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $seedPathRules = [System.Collections.Generic.List[object]]::new()
    $seedPathRuleKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($seedUrl in @($SeedUrls)) {
        if ([string]::IsNullOrWhiteSpace($seedUrl)) { continue }

        $seedForBoundary = if ($UseEvaluationValue) { Get-LinkEvaluationValue -Link $seedUrl } else { $seedUrl }
        $normalizedSeed = ConvertTo-NormalizedLink -Link $seedForBoundary
        if (-not $normalizedSeed) { continue }

        $seedHost = Get-UrlHost -Url $normalizedSeed
        if (-not $seedHost) { continue }

        [void]$hosts.Add($seedHost)

        $domain = Get-RegistrableDomain -HostName $seedHost
        if ($domain) {
            [void]$domains.Add($domain)
        }

        $pathPrefix = Get-UrlPathPrefix -Url $normalizedSeed
        if (-not [string]::IsNullOrWhiteSpace($pathPrefix)) {
            $pathRuleKey = @($seedHost, $domain, $pathPrefix) -join ([string][char]0x1F)
            if ($seedPathRuleKeys.Add($pathRuleKey)) {
                $seedPathRules.Add([pscustomobject]@{
                    Host       = $seedHost
                    Domain     = $domain
                    PathPrefix = $pathPrefix
                })
            }
        }
    }

    return [pscustomobject]@{
        Hosts         = $hosts
        Domains       = $domains
        SeedPathRules = $seedPathRules
    }
}

function Test-IsLikelyCrawlablePageUrl {
    param([AllowNull()][string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }

    try {
        $uri = [uri]$Url
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notmatch '^https?$') { return $false }

        $path = $uri.AbsolutePath
        if ([string]::IsNullOrWhiteSpace($path) -or $path.EndsWith('/')) { return $true }

        $leaf = ($path -split '/')[-1]
        if ([string]::IsNullOrWhiteSpace($leaf)) { return $true }

        # Do not crawl obvious static/binary assets as pages. They may still be
        # extracted and saved if they match SearchPattern; this only prevents
        # wasting fetches on assets that will not contain useful outbound links.
        if ($leaf -match '(?i)\.(?:css|js|mjs|json|xml|txt|csv|rss|atom|map|png|jpg|jpeg|gif|webp|svg|ico|bmp|avif|pdf|zip|7z|rar|tar|gz|tgz|bz2|xz|lha|lzh|exe|msi|dmg|pkg|deb|rpm|apk|ipa|mp3|ogg|wav|flac|mp4|webm|mov|avi|woff|woff2|ttf|otf|eot)$') {
            return $false
        }

        return $true
    }
    catch {
        return $false
    }
}

function Test-HostLooksInternalWithoutDns {
    param([AllowNull()][string]$HostName)

    if ([string]::IsNullOrWhiteSpace($HostName)) { return $true }

    $hostClean = $HostName.Trim().Trim([char[]]@('[', ']')).TrimEnd('.').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($hostClean)) { return $true }
    if ($hostClean -ieq 'localhost') { return $true }
    if ($hostClean -notmatch '\.') { return $true }
    if ($hostClean -match '(?i)(^|\.)(localhost|local|internal|lan)$' -or $hostClean -match '(?i)\.home\.arpa$') { return $true }

    $parsedIp = [System.Net.IPAddress]::None
    if ([System.Net.IPAddress]::TryParse($hostClean, [ref]$parsedIp)) {
        return (Test-IsPrivateIPAddress -IPAddress $parsedIp)
    }

    return $false
}

function Test-UrlAllowedForFollow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [ValidateSet('SameDomain', 'SameHost', 'Any')]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        $Boundary,

        [ValidateSet('Any', 'SeedPath')]
        [string]$PathScope = 'Any',

        [bool]$AllowSubdomains = $false,
        [int]$MaxSubdomainDepthValue = 0
    )

    $normalizedUrl = ConvertTo-NormalizedLink -Link $Url
    if (-not $normalizedUrl) { return $false }
    if (-not (Test-IsLikelyCrawlablePageUrl -Url $normalizedUrl)) { return $false }

    $urlHost = Get-UrlHost -Url $normalizedUrl
    if (-not $urlHost) { return $false }
    if (Test-HostLooksInternalWithoutDns -HostName $urlHost) { return $false }

    $allowedByScope = $false

    if ($Scope -eq 'Any') {
        $allowedByScope = $true
    }
    elseif ($Scope -eq 'SameHost') {
        $allowedByScope = $Boundary.Hosts.Contains($urlHost)
    }
    else {
        $rootDomain = Get-RegistrableDomain -HostName $urlHost
        if ($rootDomain -and $Boundary.Domains.Contains($rootDomain)) {
            # Default SameDomain policy: exact seed host(s), apex/root, and the common
            # www.<root> host. Other subdomains are opt-in via -FollowSubdomains.
            if ($Boundary.Hosts.Contains($urlHost) -or $urlHost -ieq $rootDomain -or $urlHost -ieq "www.$rootDomain") {
                $allowedByScope = $true
            }
            elseif ($AllowSubdomains) {
                $depth = Get-SubdomainDepthForRoot -HostName $urlHost -RootDomain $rootDomain
                $allowedByScope = ($depth -ge 1 -and ($MaxSubdomainDepthValue -eq 0 -or $depth -le $MaxSubdomainDepthValue))
            }
        }
    }

    if (-not $allowedByScope) { return $false }

    if ($PathScope -eq 'SeedPath') {
        $allowedByPath = $false

        foreach ($rule in @($Boundary.SeedPathRules)) {
            if ($null -eq $rule) { continue }
            if ([string]::IsNullOrWhiteSpace($rule.PathPrefix)) { continue }

            $samePathBoundary = $false
            if ($Scope -eq 'SameHost') {
                $samePathBoundary = ($urlHost -ieq $rule.Host)
            }
            elseif ($Scope -eq 'SameDomain') {
                $candidateRootDomain = Get-RegistrableDomain -HostName $urlHost
                $samePathBoundary = (
                    -not [string]::IsNullOrWhiteSpace($candidateRootDomain) -and
                    -not [string]::IsNullOrWhiteSpace($rule.Domain) -and
                    $candidateRootDomain -ieq $rule.Domain
                )
            }
            else {
                # In Any-domain mode, still bind SeedPath rules to the seed host.
                # Otherwise a seed /1 path would accidentally allow /1 on every
                # unrelated external site.
                $samePathBoundary = ($urlHost -ieq $rule.Host)
            }

            if ($samePathBoundary -and (Test-UrlPathUnderPrefix -Url $normalizedUrl -PathPrefix $rule.PathPrefix)) {
                $allowedByPath = $true
                break
            }
        }

        if (-not $allowedByPath) { return $false }
    }

    # Full DNS-based SSRF check is intentionally after scope filtering so an
    # ordinary SameDomain crawl does not resolve every external link on the page.
    return (-not (Test-IsPrivateUrl $normalizedUrl))
}

# ---------------------------------------------------------------------------
# RESUME & PROGRESS HELPERS
# Generates a fingerprint of the current run configuration to ensure a resumed
# run is using the same settings (otherwise we might append the wrong data).
# ---------------------------------------------------------------------------
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

# Function: Get-RunSignature
# Purpose: Concatenates all crucial params (Search mode, blacklist files, output file)
#          and hashes them so the resume progress file knows what job it belongs to.
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
        [bool]$EnforceRobotsTxt,
        [string]$RobotsUserAgent,
        [bool]$KeepDuplicates,
        [bool]$NoDuplicates,
        [bool]$KeepFragments,
        [bool]$StripRegexBeforeEvaluation,
        [AllowNull()][string]$LinkEvaluationStripRegex
    )

    $sourceSig = $Source
    $outputSig = $OutputFile

    if ($SourceType -eq "File") {
        $sourceSig = Get-SafeAbsolutePath $Source
    }
    $outputSig = Get-SafeAbsolutePath $OutputFile

    $blacklistSigPaths = @(
        @($BlacklistPaths) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { Get-SafeAbsolutePath $_ } |
            Sort-Object -Unique
    )

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
        "BlacklistPaths=$($blacklistSigPaths -join $delim)"
        "SecondFetch=$SecondFetch"
        "EnforceRobotsTxt=$EnforceRobotsTxt"
        "RobotsUserAgent=$RobotsUserAgent"
        "KeepDuplicates=$KeepDuplicates"
        "NoDuplicates=$NoDuplicates"
        "KeepFragments=$KeepFragments"
        "StripRegexBeforeEvaluation=$StripRegexBeforeEvaluation"
        "LinkEvaluationStripRegex=$LinkEvaluationStripRegex"
    ) -join "`n"

    return Get-Sha256Text $signatureText
}

# Function: Initialize-ProgressFile
# Purpose: Validates an existing progress file (for resume runs) to ensure it 
#          matches the current Signature. Loads completed URLs into memory to skip.
function Initialize-ProgressFile {
    param(
        [string]$Path,
        [string]$Signature,
        [switch]$Resume
    )

    # Use ConcurrentDictionary for thread-safety in ThrottleLimit > 1 situations
    $completed = [System.Collections.Concurrent.ConcurrentDictionary[string, byte]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ((Test-Path -LiteralPath $Path) -and $Resume) {
        # Handle 0-byte progress file from a crash during creation
        $fileInfo = Get-Item -LiteralPath $Path
        if ($fileInfo.Length -eq 0) {
            Write-Host "Progress file is empty (likely from a crash). Removing and starting fresh."
            Remove-Item -LiteralPath $Path -Force

            Set-Content -LiteralPath $Path -Value @(
                "# AE-Find-WebLinks progress file"
                "# Signature: $Signature"
                "# One completed source URL key per line"
            ) -Encoding UTF8

            Write-Host "Progress file recreated: $Path"
        }
        else {
            $safeProgressPath = Get-SafeAbsolutePath $Path
            $lineEnum = [System.IO.File]::ReadLines($safeProgressPath, [System.Text.Encoding]::UTF8).GetEnumerator()

            $signatureLine = $null
            $headerLinesChecked = 0
            try {
                while ($lineEnum.MoveNext()) {
                    $headerLinesChecked++
                    if ($lineEnum.Current -match '^# Signature:') {
                        $signatureLine = $lineEnum.Current
                        break
                    }

                    # A valid AE-Find-WebLinks progress file writes the signature near the top.
                    # Do not scan a huge accidental file forever just because -Resume pointed at it.
                    if ($headerLinesChecked -ge 5) { break }
                }

                if (-not $signatureLine) {
                    throw "Progress file exists but has no signature in the first 5 lines: $Path. Delete it or use a different -ProgressFile."
                }

                $existingSignature = ($signatureLine -replace '^# Signature:\s*', '').Trim()

                if ($existingSignature -ne $Signature) {
                    throw "Progress file belongs to a different run configuration: $Path. The search, exclude, blacklist, source, or output settings changed. Delete the progress file to start a fresh run, or rerun with the original command."
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
            "# AE-Find-WebLinks progress file"
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

# Add URL to tracker so if script dies, it doesn't scrape it again next run
function Add-CompletedProgress {
    param(
        [string]$Path,
        [string]$Url,
        $CompletedSet,
        [bool]$KeepFragments = $false
    )

    $key = Get-LinkKey -Link $Url -KeepFragments $KeepFragments

    if ([string]::IsNullOrWhiteSpace($key)) { return }

    if ($CompletedSet.TryAdd($key, [byte]0)) {
        $safePath = Get-SafeAbsolutePath $Path
        try {
            Write-FileWithRetry -FilePath $safePath -Content $key
        }
        catch {
            throw "Progress write failed for ${safePath}: $($_.Exception.Message)"
        }
    }
}

function Remove-ProgressFileIfSafe {
    param(
        [string]$Path,
        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    try {
        if (Test-Path -LiteralPath $Path) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            Write-Host "Progress file removed: $Path"
            Write-Host "Reason: $Reason"
        }
    }
    catch {
        Write-Warning "Could not remove progress file: $Path. $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# I/O RETRY HELPERS (File Operations)
# Purpose: Prevent fatal crashes just because an antivirus locked a file for 100ms.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# MAINTENANCE FUNCTIONS (Sorting & Deduplication)
# Purpose: Cleans up source files, blacklists, or output files either pre-run,
#          post-run, or via standalone script call.
# ---------------------------------------------------------------------------
function Remove-MaintenanceTempFile {
    param(
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [string]$TempFile,

        [Parameter(Mandatory=$false)]
        [string]$Reason = "maintenance temp file"
    )

    if ([string]::IsNullOrWhiteSpace($TempFile)) { return }

    try {
        if ([System.IO.File]::Exists($TempFile)) {
            Remove-Item -LiteralPath $TempFile -Force -ErrorAction Stop
            Write-Host "Removed ${Reason}: $TempFile"
        }
    }
    catch {
        Write-Warning "Could not remove ${Reason}: $TempFile. $($_.Exception.Message)"
    }
}

function Test-ProcessIdIsRunning {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )

    if ($ProcessId -le 0) { return $false }

    try {
        $null = Get-Process -Id $ProcessId -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Helper: Finds old PID-locked `.tmp` files from crashed runs and clears them
function Remove-StaleMaintenanceTempFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$BaseFiles,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 2147483647)]
        [int]$OlderThanMinutes = 60
    )

    $cutoff = (Get-Date).AddMinutes(-$OlderThanMinutes)
    $seenBaseFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($baseFile in $BaseFiles) {
        if ([string]::IsNullOrWhiteSpace($baseFile)) { continue }

        $safeBaseFile = Get-SafeAbsolutePath $baseFile
        if (-not $seenBaseFiles.Add($safeBaseFile)) { continue }

        $folder = Split-Path -Parent $safeBaseFile
        $name = Split-Path -Leaf $safeBaseFile

        if ([string]::IsNullOrWhiteSpace($folder) -or [string]::IsNullOrWhiteSpace($name)) { continue }
        if (-not [System.IO.Directory]::Exists($folder)) { continue }

        $tempNameRegex = '^' + [regex]::Escape($name) + '\.(?<pid>\d+)\.(?:dedup|sort)\.tmp$'

        # Do not use -Filter with the base filename embedded in a wildcard pattern:
        # on non-Windows filesystems a literal character such as [ or * can be part
        # of the filename and would otherwise broaden the cleanup match.
        $tempFiles = @(
            Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match $tempNameRegex }
        )

        foreach ($tempFile in $tempFiles) {
            $removeTemp = $false
            $reason = "stale maintenance temp file"
            $pidWasParsed = $false
            $pidIsRunning = $false

            $match = [regex]::Match($tempFile.Name, $tempNameRegex)
            if ($match.Success) {
                $tempPid = 0
                if ([int]::TryParse($match.Groups['pid'].Value, [ref]$tempPid)) {
                    $pidWasParsed = $true
                    $pidIsRunning = Test-ProcessIdIsRunning -ProcessId $tempPid

                    if (-not $pidIsRunning) {
                        $removeTemp = $true
                        $reason = "orphaned maintenance temp file"
                    }
                }
            }

            # Never delete a temp file owned by a currently running process just
            # because the operation has taken longer than the stale-time cutoff.
            if (-not $removeTemp -and (-not $pidWasParsed -or -not $pidIsRunning) -and $tempFile.LastWriteTime -lt $cutoff) {
                $removeTemp = $true
            }

            if ($removeTemp) {
                Remove-MaintenanceTempFile -TempFile $tempFile.FullName -Reason $reason
            }
        }
    }
}

# Function: Remove-FileDuplicatesFast
# Purpose: Reads a file line-by-line, tracks seen URL keys in memory, and writes
#          unique entries to a temporary `.tmp` file, then replaces the original.
function Remove-FileDuplicatesFast {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [bool]$KeepFragments = $false
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

    $writeSucceeded = $false
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
            $key = Get-LinkKey -Link $trimmed -KeepFragments $KeepFragments
            if ([string]::IsNullOrWhiteSpace($key)) {
                # Not a valid URL — keep as-is using raw string dedup
                $key = $trimmed
            }

            if ($seenKeys.Add($key)) {
                $writer.WriteLine((Get-LinkWriteValue -Link $trimmed -KeepFragments $KeepFragments))
                $linesKept++
            }
            else {
                $duplicatesRemoved++
            }
        }

        $writeSucceeded = $true
        Write-Host "  Kept: $linesKept | Removed: $duplicatesRemoved"
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $writer) { $writer.Dispose() }

        if (-not $writeSucceeded) {
            Remove-MaintenanceTempFile -TempFile $tempFile -Reason "failed dedup temp file"
        }
    }

    $moveSucceeded = $false
    try {
        for ($moveAttempt = 1; $moveAttempt -le $Script:FileMoveRetryCount; $moveAttempt++) {
            try {
                Move-Item -LiteralPath $tempFile -Destination $safePath -Force
                $moveSucceeded = $true
                break
            } catch {
                if ($moveAttempt -eq $Script:FileMoveRetryCount) { throw }
                if ($Script:FileMoveRetryDelayMs -gt 0) {
                    Start-Sleep -Milliseconds $Script:FileMoveRetryDelayMs
                }
            }
        }
    }
    catch {
        if (-not $moveSucceeded) {
            Remove-MaintenanceTempFile -TempFile $tempFile -Reason "failed dedup temp file"
        }
        throw
    }

    Write-Host "Deduplication complete."
}

# Function: Sort-FileFast
# Purpose: Uses memory arrays to alphabetize files efficiently (skipping huge ones)
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

    $sortReader = $null
    try {
        $sortReader = [System.IO.StreamReader]::new($safePath, [System.Text.Encoding]::UTF8)
        while ($null -ne ($line = $sortReader.ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith("#")) {
                $comments.Add($trimmed)
            }
            else {
                $lines.Add($trimmed)
            }
        }
    }
    finally {
        if ($null -ne $sortReader) { $sortReader.Dispose() }
    }

    $lines.Sort([System.StringComparer]::OrdinalIgnoreCase)
    if ($SortDirection -eq "Descending") {
        $lines.Reverse()
    }

    $tempFile = "$safePath.$PID.sort.tmp"
    $writer = $null
    $writeSucceeded = $false
    try {
        $writer = [System.IO.StreamWriter]::new($tempFile, $false, [System.Text.Encoding]::UTF8)
        # Write comments first (preserve headers)
        foreach ($c in $comments) { $writer.WriteLine($c) }
        # Then sorted content
        foreach ($l in $lines) { $writer.WriteLine($l) }
        $writeSucceeded = $true
    }
    finally {
        if ($null -ne $writer) { $writer.Dispose() }

        if (-not $writeSucceeded) {
            Remove-MaintenanceTempFile -TempFile $tempFile -Reason "failed sort temp file"
        }
    }

    $moveSucceeded = $false
    try {
        for ($moveAttempt = 1; $moveAttempt -le $Script:FileMoveRetryCount; $moveAttempt++) {
            try {
                Move-Item -LiteralPath $tempFile -Destination $safePath -Force
                $moveSucceeded = $true
                break
            } catch {
                if ($moveAttempt -eq $Script:FileMoveRetryCount) { throw }
                if ($Script:FileMoveRetryDelayMs -gt 0) {
                    Start-Sleep -Milliseconds $Script:FileMoveRetryDelayMs
                }
            }
        }
    }
    catch {
        if (-not $moveSucceeded) {
            Remove-MaintenanceTempFile -TempFile $tempFile -Reason "failed sort temp file"
        }
        throw
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

# Helper wrapper connecting dedupe/sort together into one pass
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
        [string]$SortDirection = "Ascending",

        [Parameter(Mandatory=$false)]
        [bool]$KeepFragments = $false
    )

    if (-not $Deduplicate -and -not $Sort) { return }

    Remove-StaleMaintenanceTempFiles -BaseFiles $FilePath -OlderThanMinutes 60

    foreach ($file in @(Get-UniqueMaintenanceFiles -FilePath $FilePath)) {
        if (-not [System.IO.File]::Exists($file)) {
            Write-Warning "File not found: $file"
            continue
        }

        if ($Deduplicate) {
            Remove-FileDuplicatesFast -FilePath $file -KeepFragments $KeepFragments
        }

        if ($Sort) {
            Sort-FileFast -FilePath $file -SortDirection $SortDirection
        }
    }
}

function Get-ProcessingMaintenanceFiles {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Url", "File")]
        [string]$SourceTypeValue,

        [AllowNull()]
        [string]$SourcePath,

        [AllowNull()]
        [string]$OutputPath,

        [AllowNull()]
        [string[]]$BlacklistPaths
    )

    $list = [System.Collections.Generic.List[string]]::new()

    if ($SourceTypeValue -eq "File" -and -not [string]::IsNullOrWhiteSpace($SourcePath)) {
        [void]$list.Add($SourcePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        [void]$list.Add($OutputPath)
    }

    if ($BlacklistPaths) {
        foreach ($blFile in $BlacklistPaths) {
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
        [string]$Phase,

        [Parameter(Mandatory=$true)]
        [ValidateSet("None", "Start", "End", "Both")]
        [string]$DeduplicateWhenValue,

        [Parameter(Mandatory=$true)]
        [ValidateSet("None", "Start", "End", "Both")]
        [string]$SortWhenValue,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Ascending", "Descending")]
        [string]$SortDirectionValue,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Url", "File")]
        [string]$SourceTypeValue,

        [AllowNull()]
        [string]$SourcePath,

        [AllowNull()]
        [string]$OutputPath,

        [AllowNull()]
        [string[]]$BlacklistPaths,

        [Parameter(Mandatory=$false)]
        [bool]$KeepFragments = $false
    )

    $doDeduplicate = Test-MaintenancePhaseEnabled -When $DeduplicateWhenValue -Phase $Phase
    $doSort = Test-MaintenancePhaseEnabled -When $SortWhenValue -Phase $Phase

    if (-not $doDeduplicate -and -not $doSort) { return }

    $filesToMaintain = @(Get-ProcessingMaintenanceFiles `
        -SourceTypeValue $SourceTypeValue `
        -SourcePath $SourcePath `
        -OutputPath $OutputPath `
        -BlacklistPaths $BlacklistPaths)
    if ($filesToMaintain.Count -eq 0) { return }

    Write-Host ""
    Write-Host "--- File maintenance: $Phase phase ---"
    Invoke-FileMaintenance `
        -FilePath $filesToMaintain `
        -Deduplicate:$doDeduplicate `
        -Sort:$doSort `
        -SortDirection $SortDirectionValue `
        -KeepFragments $KeepFragments
    Write-Host "--- File maintenance complete: $Phase phase ---"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# SSRF PROTECTION & DNS SECURITY
# Purpose: Ensures the script won't scrape an internal LAN IP (e.g. 192.168.x.x)
#          or localhost, acting as a blind proxy for attackers.
# ---------------------------------------------------------------------------
# #36: Check if an IP/URL targets a private/internal network (SSRF protection)
function Test-IsPrivateIPAddress {
    param([System.Net.IPAddress]$IPAddress)

    if ($null -eq $IPAddress) { return $false }

    if ([System.Net.IPAddress]::IsLoopback($IPAddress)) { return $true }

    $ip = $IPAddress
    $bytes = $ip.GetAddressBytes()

    # IPv4-mapped IPv6 (::ffff:a.b.c.d) must be tested as IPv4 too.
    if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6 -and $bytes.Length -eq 16) {
        $isMapped = $true
        for ($i = 0; $i -lt 10; $i++) {
            if ($bytes[$i] -ne 0) { $isMapped = $false; break }
        }

        if ($isMapped -and $bytes[10] -eq 0xff -and $bytes[11] -eq 0xff) {
            $mappedBytes = [byte[]]@($bytes[12], $bytes[13], $bytes[14], $bytes[15])
            $ip = [System.Net.IPAddress]::new($mappedBytes)
            $bytes = $ip.GetAddressBytes()
        }
    }

    if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
        # IPv4 private, loopback, link-local, unspecified, carrier-grade NAT,
        # benchmarking, multicast, and reserved ranges should never be fetched.
        if ($bytes[0] -eq 0) { return $true }
        if ($bytes[0] -eq 10) { return $true }
        if ($bytes[0] -eq 127) { return $true }
        if ($bytes[0] -eq 169 -and $bytes[1] -eq 254) { return $true }
        if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) { return $true }
        if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) { return $true }
        # IETF special-purpose, documentation, and benchmarking ranges.
        if ($bytes[0] -eq 100 -and $bytes[1] -ge 64 -and $bytes[1] -le 127) { return $true }
        if ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0) { return $true }
        if ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -eq 2) { return $true }
        if ($bytes[0] -eq 198 -and ($bytes[1] -eq 18 -or $bytes[1] -eq 19)) { return $true }
        if ($bytes[0] -eq 198 -and $bytes[1] -eq 51 -and $bytes[2] -eq 100) { return $true }
        if ($bytes[0] -eq 203 -and $bytes[1] -eq 0 -and $bytes[2] -eq 113) { return $true }
        if ($bytes[0] -ge 224) { return $true }
    }
    elseif ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
        $allZero = $true
        foreach ($b in $bytes) {
            if ($b -ne 0) { $allZero = $false; break }
        }

        if ($allZero) { return $true }
        if ($ip.IsIPv6LinkLocal -or $ip.IsIPv6SiteLocal) { return $true }
        # fc00::/7 unique local addresses
        if (($bytes[0] -band 0xfe) -eq 0xfc) { return $true }
        # 2001:db8::/32 documentation prefix and 2002::/16 6to4 relay prefix.
        if ($bytes[0] -eq 0x20 -and $bytes[1] -eq 0x01 -and $bytes[2] -eq 0x0d -and $bytes[3] -eq 0xb8) { return $true }
        if ($bytes[0] -eq 0x20 -and $bytes[1] -eq 0x02) { return $true }
        # ff00::/8 multicast
        if ($bytes[0] -eq 0xff) { return $true }
    }

    return $false
}

function Test-IsPrivateUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }

    try {
        $uri = [uri]$Url
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notmatch '^https?$') { return $false }

        $host_ = $uri.Host
        if ([string]::IsNullOrWhiteSpace($host_)) { return $false }
        $host_ = $host_.Trim([char[]]@('[', ']')).TrimEnd('.')

        # Always block localhost regardless of representation, including localhost.
        if ($host_ -ieq 'localhost') { return $true }

        $parsedIp = [System.Net.IPAddress]::None
        if ([System.Net.IPAddress]::TryParse($host_, [ref]$parsedIp)) {
            return (Test-IsPrivateIPAddress -IPAddress $parsedIp)
        }

        # Single-label and common local-only names are internal in practice.
        # Do not let OS search suffixes or mDNS/enterprise DNS turn them into network requests.
        if ($host_ -notmatch '\.') { return $true }
        if ($host_ -match '(?i)(^|\.)(localhost|local|internal|lan)$' -or $host_ -match '(?i)\.home\.arpa$') {
            return $true
        }

        # Resolve DNS to catch public-looking names that map to internal IPs.
        # Use the async DNS API with a hard wait timeout. The synchronous
        # GetHostAddresses() call ignores -TimeoutSeconds entirely and blocks the
        # worker thread on the OS resolver default (often 15-30s) when a hostile
        # or broken authoritative server stalls the response. With ThrottleLimit
        # > 1 a handful of tarpit URLs in a source list could otherwise consume
        # every worker. Wait() returning false abandons our wait but does not
        # cancel the task -- the OS resolver call continues until it gives up
        # naturally. We treat timeout as "non-resolvable, fail open" because the
        # subsequent web request honours -TimeoutSeconds and will fail cleanly.
        $ips = $null
        try {
            $dnsTask = [System.Net.Dns]::GetHostAddressesAsync($host_)
            if (-not $dnsTask.Wait([TimeSpan]::FromSeconds($Script:DnsResolutionTimeoutSeconds))) {
                return $false
            }
            $ips = $dnsTask.Result
        }
        catch {
            # AggregateException unwrapping is unnecessary -- any DNS failure
            # means the subsequent web request will fail natively too.
            return $false
        }

        foreach ($ip in $ips) {
            if (Test-IsPrivateIPAddress -IPAddress $ip) { return $true }
        }
    }
    catch { }

    return $false
}

function Remove-Bom {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if ($Text[0] -eq [char]0xFEFF) {
        return $Text.Substring(1)
    }
    return $Text
}

# #28: Validate path and leaf filename do not contain illegal characters
function Test-ValidFilePath {
    param([AllowNull()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }

    $invalidPathChars = [System.IO.Path]::GetInvalidPathChars()
    foreach ($c in $invalidPathChars) {
        if ($Path.IndexOf($c) -ge 0) { return $false }
    }

    # GetInvalidPathChars() is intentionally permissive on Windows and does not
    # catch filename-only illegal characters such as ?, *, <, >, or |. Validate
    # the leaf separately so bad output/log/source paths fail with a clear error.
    try {
        $leaf = Split-Path -Path $Path -Leaf
    }
    catch {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($leaf)) { return $false }

    $invalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($c in $invalidFileNameChars) {
        if ($leaf.IndexOf($c) -ge 0) { return $false }
    }

    return $true
}

# Decode JS-escaped URLs (\/ and \u002F).
# Unwraps search engine redirects (Google/Bing) and strips tracking parameters
function Resolve-SearchEngineLink {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }

    # 1. Google Search Redirects (e.g., /url?q=https://...)
    if ($Url -match '(?i)^(?:https?://(?:www\.)?google\.[a-z.]{2,12})?/url\?(?:.*?&)?(?:q|url)=([^&]+)') {
        $Url = [System.Net.WebUtility]::UrlDecode($matches[1])
    }
    # 2. Bing Click Tracking (e.g., /ck/a?!...&u=a1aHR0cHM...)
    elseif ($Url -match '(?i)^https?://(?:www\.)?bing\.com/ck/a\?.*?[?&]u=([a-zA-Z0-9\-_=]+)') {
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
        $Url = $Url -replace '\?&', '?'
        $Url = $Url -replace '&&+', '&'
        $Url = $Url -replace '&$', ''
        $Url = $Url -replace '\?$', ''
    }

    return $Url
}

function ConvertFrom-JsUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }

    $Value = $Value `
        -replace '\\/', '/' `
        -replace '\\x2[Ff]', '/' `
        -replace '\\x3[Aa]', ':' `
        -replace '\\x3[Dd]', '=' `
        -replace '\\x3[Ff]', '?' `
        -replace '\\x26', '&' `
        -replace '\\x23', '#' `
        -replace '\\x25', '%' `
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

function Test-IsLikelyRelativeAssetPath {
    param([AllowNull()][string]$Link)

    if ([string]::IsNullOrWhiteSpace($Link)) { return $false }

    $candidate = $Link.Trim()

    # Do not rewrite absolute/protocol-style values here.
    if ($candidate -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') { return $false }

    # The raw URL regex can legitimately see relative asset names such as
    # app.min.js, assets/app.min.js, style.css, game.zip, or image.webp.
    # Some of those extensions are also real TLDs, so they must be resolved
    # relative to the page before the bare-domain rule gets a chance to turn
    # them into https://app.min.js.
    $pathPart = ($candidate -split '[?#]', 2)[0]
    if ([string]::IsNullOrWhiteSpace($pathPart)) { return $false }

    $normalisedPath = $pathPart -replace '\\', '/'
    $trimmedPath = $normalisedPath.TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($trimmedPath)) { return $false }

    # If the path has multiple segments and the first segment looks like a real
    # bare domain, leave it for the bare-domain normaliser. This avoids turning
    # example.com/assets/app.js into a relative path under the current page.
    # A single-segment path (e.g. app.js, bar.png, news.html) is treated as a
    # relative asset so that extensions which are also TLDs (.js, .zip, .mov)
    # do not get turned into bogus absolute URLs like https://app.js/.
    $firstSegment = ($trimmedPath -split '/', 2)[0]
    if ($trimmedPath.Contains('/') -and `
        $firstSegment -match '^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$') {
        return $false
    }

    $leaf = ($trimmedPath -split '/')[-1]
    if ([string]::IsNullOrWhiteSpace($leaf)) { return $false }

    # Asset extensions cover both static assets and common HTML-rendering
    # extensions (html, htm, php, aspx, ...). The latter are included so that
    # bare relative pages such as news.html resolve against BaseUri instead of
    # being misinterpreted as bare domains by the rule that follows.
    $assetExtensionPattern = '(?i)\.(?:css|js|mjs|json|xml|txt|csv|rss|atom|map|png|jpg|jpeg|gif|webp|svg|ico|bmp|avif|pdf|zip|7z|rar|tar|gz|tgz|bz2|xz|lha|lzh|exe|msi|dmg|pkg|deb|rpm|apk|ipa|mp3|ogg|wav|flac|mp4|webm|mov|avi|woff|woff2|ttf|otf|eot|html|htm|xhtml|shtml|php|aspx)$'
    return ($leaf -match $assetExtensionPattern)
}

function Limit-NormalizedLinkLength {
    param([AllowNull()][string]$Link)

    if ($null -eq $Link) { return $null }

    if ($Script:MaxUrlLength -gt 0 -and $Link.Length -gt $Script:MaxUrlLength) {
        return $null
    }

    return $Link
}

# ---------------------------------------------------------------------------
# Function: ConvertTo-NormalizedLink
# Purpose: The core sanitizer. Takes extremely messy strings found in raw HTML 
#          and turns them into perfectly formatted HTTP/HTTPS links (or null).
# ---------------------------------------------------------------------------
function ConvertTo-NormalizedLink {
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
    if ($Script:MaxUrlLength -gt 0 -and $link.Length -gt $Script:MaxUrlLength) { return $null }

    # Unwrap search engine redirects and strip tracking parameters
    $link = Resolve-SearchEngineLink -Url $link
    if ([string]::IsNullOrWhiteSpace($link)) { return $null }

    # Trim punctuation commonly captured after URLs in prose, but do not remove the
    # closing bracket of a valid IPv6 literal such as http://[::1].
    if ($link -match '^https?://\[[^\]]+\](?::\d+)?(?:[/?#].*)?$') {
        $link = $link.TrimEnd('.', ',', ';', ':', ')', '}', '"', "'")
    }
    else {
        $link = $link.TrimEnd('.', ',', ';', ':', ')', ']', '}', '"', "'")
    }

    if ([string]::IsNullOrWhiteSpace($link)) { return $null }

    # Ignore non-web protocols
    if ($link -match '^(mailto|tel|javascript|data|ftp|file):') { return $null }

    # Ignore page anchors
    if ($link.StartsWith("#")) { return $null }

    # Already absolute http/https. Validate before returning so malformed values
    # such as http://[::1 are not passed into the fetch layer.
    if ($link -match '^https?://') {
        try {
            $absolute = [uri]$link
            if ($absolute.IsAbsoluteUri -and $absolute.Scheme -match '^https?$') {
                return (Limit-NormalizedLinkLength -Link $absolute.AbsoluteUri)
            }
        }
        catch { }
        return $null
    }

    # Protocol-relative (e.g., //example.com/script.js)
    if ($link -match '^//') {
        $candidate = if ($null -ne $BaseUri) { "$($BaseUri.Scheme):$link" } else { "https:$link" }
        return (ConvertTo-NormalizedLink -Link $candidate)
    }

    # Bare www
    if ($link -match '^www\.') { return (ConvertTo-NormalizedLink -Link "https://$link") }

    # Relative asset filename. Resolve this before the bare-domain rule because
    # some valid file extensions also exist as modern TLDs (.js, .zip, .mov, etc.).
    if ($null -ne $BaseUri -and (Test-IsLikelyRelativeAssetPath -Link $link)) {
        try {
            $absolute = [uri]::new($BaseUri, $link)
            if ($absolute.Scheme -match '^https?$') { return (Limit-NormalizedLinkLength -Link $absolute.ToString()) }
        }
        catch { return $null }
    }

    # Bare domain, including query/fragment-only URLs such as example.com?x=1.
    # Without this, those values are wrongly treated as relative paths.
    # The body uses [a-zA-Z0-9.-]* (zero or more) rather than + so that single-
    # letter shortener domains like t.co, g.co, and j.mp match. The trade-off
    # is that prose like "section 1.io" can produce false positives when the
    # value is fed in directly. Inside RegexRawUrl the lookbehind blocks the
    # same pattern when it appears as part of a path or word-boundary context.
    if ($link -match '^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}(:\d+)?([/?#].*)?$') {
        return (ConvertTo-NormalizedLink -Link "https://$link")
    }

    # Relative link (e.g. /path/to/page.html)
    if ($null -ne $BaseUri) {
        try {
            $absolute = [uri]::new($BaseUri, $link)
            if ($absolute.Scheme -match '^https?$') { return (Limit-NormalizedLinkLength -Link $absolute.ToString()) }
        }
        catch { return $null }
    }

    return $null
}

function Test-BlacklistAppliesToInput {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Input", "Output", "Both")]
        [string]$Scope
    )

    return ($Scope -eq "Input" -or $Scope -eq "Both")
}

function Test-BlacklistAppliesToOutput {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Input", "Output", "Both")]
        [string]$Scope
    )

    return ($Scope -eq "Output" -or $Scope -eq "Both")
}

function Test-IsBlacklisted {
    param(
        [string]$Url,
        $BlacklistSet,
        [bool]$KeepFragments = $false,
        [bool]$UseEvaluationValue = $false
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    if ($null -eq $BlacklistSet -or $BlacklistSet.Count -eq 0) { return $false }

    return $BlacklistSet.ContainsKey((Get-LinkKey -Link $Url -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue))
}

# ---------------------------------------------------------------------------
# Invoke-WebRequestWithRetry
#   - Retries up to $MaxRetries times on failure, with $WaitSec between
#     attempts. On 429/503 with Retry-After the server's wait is honoured up
#     to $MaxRetryAfterSecondsValue.
#   - Uses a WebRequestSession so cookies persist across redirects.
#   - Sends every request with -MaximumRedirection 0 and follows redirects
#     manually so each Location target can be SSRF-validated against
#     Test-IsPrivateUrl before another network call. Honours both HTTP 3xx
#     redirects and <meta http-equiv="refresh"> redirects.
#   - On PS 5.1 the cmdlet throws InvalidOperationException with FQEID
#     MaximumRedirectExceeded on a 3xx and discards the response object,
#     so when that FQEID is detected the redirect target is recovered
#     through Get-RedirectTargetViaRawRequest (raw HttpWebRequest) and the
#     same SSRF validation is applied. See that function for details.
#   - When $DoSecondFetch is true, silently fetches the page a second time
#     after $SecondWait seconds using the same session, and keeps the larger
#     response only if its media type is also text-like (so a binary second
#     response cannot displace a valid HTML first response). This helps
#     with cookie-walls and session-gated pages. It does NOT execute
#     JavaScript or wait for client-side rendering.
# ---------------------------------------------------------------------------

function Test-IsRegexTimeoutException {
    param([AllowNull()][object]$ErrorObject)

    if ($null -eq $ErrorObject) { return $false }

    $ex = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        $ErrorObject.Exception
    }
    elseif ($ErrorObject.PSObject.Properties['Exception']) {
        $ErrorObject.Exception
    }
    else {
        $ErrorObject
    }

    while ($null -ne $ex) {
        if ($ex -is [System.Text.RegularExpressions.RegexMatchTimeoutException]) {
            return $true
        }

        $ex = $ex.InnerException
    }

    return $false
}

function Get-RegexMatchesSafe {
    param(
        [Parameter(Mandatory=$true)]
        [System.Text.RegularExpressions.Regex]$Regex,

        [AllowNull()]
        [string]$InputText,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if ($null -eq $InputText) { return @() }

    try {
        return @($Regex.Matches($InputText))
    }
    catch {
        if (Test-IsRegexTimeoutException $_) {
            Write-Host "  WARNING: Regex timed out while scanning $Name; skipping that extraction pass."
            return @()
        }

        throw
    }
}

function Get-RegexFirstMatchSafe {
    param(
        [Parameter(Mandatory=$true)]
        [System.Text.RegularExpressions.Regex]$Regex,

        [AllowNull()]
        [string]$InputText,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if ($null -eq $InputText) { return $null }

    try {
        return $Regex.Match($InputText)
    }
    catch {
        if (Test-IsRegexTimeoutException $_) {
            Write-Host "  WARNING: Regex timed out while scanning $Name; skipping that extraction pass."
            return $null
        }

        throw
    }
}

function Split-SrcsetValue {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }

    $items = New-Object System.Collections.Generic.List[string]

    foreach ($entry in ($Value -split ',')) {
        $candidate = $entry.Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

        # srcset candidates are "url [descriptor]". Keep only the URL token.
        $parts = $candidate -split '\s+'
        if ($parts.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($parts[0])) {
            [void]$items.Add($parts[0])
        }
    }

    return @($items)
}

function Add-FoundLinkCandidate {
    param(
        # Empty lists are valid here: many pages call this before any previous
        # extraction pass has added a URL. Keeping this non-mandatory avoids
        # PowerShell rejecting an empty generic List before the first candidate
        # can be appended.
        [AllowNull()]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$List,

        [AllowNull()]
        [string]$Value,

        [switch]$Srcset
    )

    if ($null -eq $List) {
        throw "Internal error: Add-FoundLinkCandidate was called without a target list."
    }

    if ([string]::IsNullOrWhiteSpace($Value)) { return }

    if ($Srcset) {
        foreach ($candidate in (Split-SrcsetValue -Value $Value)) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                [void]$List.Add($candidate)
            }
        }
        return
    }

    [void]$List.Add($Value)
}


function Get-NormalizedUrlCandidatesFromText {
    param(
        [AllowNull()]
        [string]$Text
    )

    # Source-list files are often copied from browser/dev-tool output, CSV/log
    # files, or minified HTML. Treat each non-comment line as text and extract
    # every URL-like value from it instead of assuming the whole line is exactly
    # one URL. A plain one-URL-per-line file still works exactly as before.
    $results = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Add-CandidateFromText {
        param([AllowNull()][string]$CandidateText)

        if ([string]::IsNullOrWhiteSpace($CandidateText)) { return }

        $candidate = $CandidateText.Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) { return }

        # Trim separators commonly found in copied lists, CSV/TSV, Markdown,
        # quoted strings, and logs. ConvertTo-NormalizedLink does its own URL
        # cleanup too; this just improves multi-URL line extraction.
        $candidate = $candidate.Trim([char[]]@(' ', "`t", '"', "'", '<', '>', '[', ']', '(', ')', '{', '}', ',', ';', '|'))
        if ([string]::IsNullOrWhiteSpace($candidate)) { return }

        $normalizedCandidate = ConvertTo-NormalizedLink -Link $candidate
        if (-not $normalizedCandidate) { return }

        $candidateKey = $normalizedCandidate
        if ($seen.Add($candidateKey)) {
            [void]$results.Add($normalizedCandidate)
        }
    }

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $lineText = $Text.Trim()
    if ([string]::IsNullOrWhiteSpace($lineText)) { return @() }

    # Fast path: preserve old behaviour for a clean one-URL-per-line input file.
    Add-CandidateFromText -CandidateText $lineText

    # Also handle simple lists that use whitespace, comma, semicolon, or pipe as
    # separators. This catches files where many URLs are on one physical line.
    foreach ($token in ($lineText -split '[\s,;|]+')) {
        Add-CandidateFromText -CandidateText $token
    }

    # Finally scan the whole line with the script's broad URL extractor so URLs
    # embedded in HTML attributes, Markdown, logs, or CSV text are still found.
    if ($null -ne $global:RegexRawUrl) {
        foreach ($match in (Get-RegexMatchesSafe -Regex $global:RegexRawUrl -InputText $lineText -Name "source-list URL extraction")) {
            $rawMatch = $match.Value

            # RegexRawUrl is intentionally generous for page scraping. In list
            # files that can make it capture "url1,url2" as one value, so split
            # on common list separators before normalising.
            foreach ($piece in ($rawMatch -split '[,;|]+')) {
                Add-CandidateFromText -CandidateText $piece
            }
        }
    }

    return @($results.ToArray())
}

function New-FindWebLinksRequestSession {
    # Keep the session focused on cookies/session state. Proxy handling is
    # passed explicitly to Invoke-WebRequest for PowerShell 5.1/7 compatibility;
    # WebRequestSession.Proxy is not consistently available across versions.
    return (New-Object Microsoft.PowerShell.Commands.WebRequestSession)
}

# Recover the redirect target for a URL that PowerShell 5.1's Invoke-WebRequest
# refuses to surface. PS 5.1 throws InvalidOperationException with FQEID
# "MaximumRedirectExceeded" when a 3xx is returned under -MaximumRedirection 0,
# and -- unlike PS 7+ -- it does NOT attach the response object to the
# exception. The redirect's Location header is therefore unreachable through
# the normal $_.Exception.Response path. This helper bypasses the cmdlet
# entirely with a raw HttpWebRequest configured with AllowAutoRedirect=$false,
# which returns the 3xx response cleanly so we can read the Location header
# and validate the target before another network call.
#
# Returns @{StatusCode = <int>; Location = <string>} on success. Throws on
# unrecoverable errors (network failure, invalid URL). The caller is expected
# to fall through to normal retry logic if the helper throws or returns a
# non-redirect status.
function Get-RedirectTargetViaRawRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$UserAgent,
        [AllowNull()][hashtable]$Headers,
        [AllowNull()][object]$Session,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [AllowNull()][string]$ProxyUrl
    )

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = 'GET'
    $request.AllowAutoRedirect = $false
    $request.UserAgent = $UserAgent
    $request.Timeout = $TimeoutSec * 1000
    $request.ReadWriteTimeout = $TimeoutSec * 1000

    # Mirror the script's normal request headers. A handful of headers are
    # restricted on HttpWebRequest and must be set via dedicated properties
    # rather than through the Headers collection; the rest go through Add().
    if ($null -ne $Headers) {
        foreach ($key in @($Headers.Keys)) {
            $valueStr = [string]$Headers[$key]
            $keyLower = ([string]$key).ToLowerInvariant()
            if     ($keyLower -eq 'accept')         { $request.Accept = $valueStr }
            elseif ($keyLower -eq 'user-agent')     { } # already set on the property above
            elseif ($keyLower -eq 'host')           { $request.Host = $valueStr }
            elseif ($keyLower -eq 'referer')        { $request.Referer = $valueStr }
            elseif ($keyLower -eq 'content-type')   { $request.ContentType = $valueStr }
            elseif ($keyLower -eq 'connection')     { } # restricted; HttpWebRequest manages
            elseif ($keyLower -eq 'content-length') { } # restricted; computed
            else {
                try { $request.Headers.Add([string]$key, $valueStr) }
                catch { } # silently skip headers HttpWebRequest does not accept this way
            }
        }
    }

    # Reuse cookies from the script's WebRequestSession so cookie-walled
    # redirects are followed with the same identity as the original request.
    if ($null -ne $Session -and $null -ne $Session.Cookies) {
        $request.CookieContainer = $Session.Cookies
    }

    if (-not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        try {
            $request.Proxy = New-Object System.Net.WebProxy ($ProxyUrl, $true)
        }
        catch { } # bad proxy URL falls back to default proxy resolution
    }

    $rawResponse = $null
    try {
        try {
            $rawResponse = $request.GetResponse()
        }
        catch [System.Net.WebException] {
            # 3xx/4xx/5xx responses raise WebException with the response attached.
            # That is exactly what we want -- pull the response off the exception
            # and continue. Only re-throw when there is no response to inspect.
            if ($null -ne $_.Exception.Response) {
                $rawResponse = $_.Exception.Response
            } else {
                throw
            }
        }

        return [pscustomobject]@{
            StatusCode = [int]$rawResponse.StatusCode
            Location   = $rawResponse.Headers['Location']
        }
    }
    finally {
        if ($null -ne $rawResponse) {
            try { $rawResponse.Close() } catch { }
        }
    }
}

function Get-FindWebLinksProxyParameters {
    param(
        [AllowNull()]
        [string]$ProxyUrl
    )

    $params = @{}

    if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
        return $params
    }

    try {
        $proxyUri = [uri]$ProxyUrl
        if (-not $proxyUri.IsAbsoluteUri -or [string]::IsNullOrWhiteSpace($proxyUri.Scheme)) {
            throw "Proxy URI must be absolute."
        }
        # Invoke-WebRequest's -Proxy parameter only understands HTTP-style
        # proxies. Reject ftp://, file://, socks5://, etc. up-front rather than
        # producing a confusing downstream error from the cmdlet.
        if ($proxyUri.Scheme -notmatch '^(?i)https?$') {
            throw "Proxy scheme must be http or https. Got: $($proxyUri.Scheme)"
        }

        $proxyForRequest = $proxyUri.AbsoluteUri

        if (-not [string]::IsNullOrWhiteSpace($proxyUri.UserInfo)) {
            $creds = $proxyUri.UserInfo -split ':', 2
            $user = [System.Net.WebUtility]::UrlDecode($creds[0])
            $pass = if ($creds.Count -eq 2) { [System.Net.WebUtility]::UrlDecode($creds[1]) } else { "" }

            if (-not [string]::IsNullOrWhiteSpace($user)) {
                $securePass = ConvertTo-SecureString -String $pass -AsPlainText -Force
                $params['ProxyCredential'] = [System.Management.Automation.PSCredential]::new($user, $securePass)

                # Strip credentials from the proxy URI supplied to the cmdlet.
                $builder = [System.UriBuilder]::new($proxyUri)
                $builder.UserName = ""
                $builder.Password = ""
                $proxyForRequest = $builder.Uri.AbsoluteUri
            }
        }

        $params['Proxy'] = $proxyForRequest
        return $params
    }
    catch {
        throw "Invalid -Proxy value '$ProxyUrl'. Use a full proxy URL such as http://proxy:8080 or http://user:pass@proxy:8080. $($_.Exception.Message)"
    }
}

function Get-ResponseStatusCode {
    param([AllowNull()][object]$Response)

    if ($null -eq $Response) { return $null }

    foreach ($propertyName in @('StatusCode', 'Status')) {
        try {
            $prop = $Response.PSObject.Properties[$propertyName]
            if ($null -ne $prop -and $null -ne $prop.Value) {
                return [int]$prop.Value
            }
        }
        catch { }
    }

    try {
        $baseProp = $Response.PSObject.Properties['BaseResponse']
        if ($null -ne $baseProp -and $null -ne $baseProp.Value) {
            return (Get-ResponseStatusCode -Response $baseProp.Value)
        }
    }
    catch { }

    return $null
}

function Get-ResponseHeaderValue {
    param(
        [AllowNull()][object]$Response,
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if ($null -eq $Response) { return $null }

    $headers = $null
    try {
        $headersProp = $Response.PSObject.Properties['Headers']
        if ($null -ne $headersProp) { $headers = $headersProp.Value }
    }
    catch { }

    if ($null -eq $headers) {
        try {
            $baseProp = $Response.PSObject.Properties['BaseResponse']
            if ($null -ne $baseProp -and $null -ne $baseProp.Value) {
                return (Get-ResponseHeaderValue -Response $baseProp.Value -Name $Name)
            }
        }
        catch { }
        return $null
    }

    $value = $null
    try { $value = $headers[$Name] } catch { }

    if ($null -eq $value) {
        try {
            $tryValues = $null
            if ($headers.TryGetValues($Name, [ref]$tryValues)) {
                $value = @($tryValues)[0]
            }
        }
        catch { }
    }

    if ($null -eq $value) {
        try {
            foreach ($key in $headers.Keys) {
                if ([string]$key -ieq $Name) {
                    $value = $headers[$key]
                    break
                }
            }
        }
        catch { }
    }

    if ($null -eq $value) {
        try {
            $contentProp = $Response.PSObject.Properties['Content']
            if ($null -ne $contentProp -and $null -ne $contentProp.Value -and $null -ne $contentProp.Value.Headers) {
                return (Get-ResponseHeaderValue -Response $contentProp.Value -Name $Name)
            }
        }
        catch { }
    }

    if ($value -is [array]) { $value = $value[0] }
    if ($null -eq $value) { return $null }

    $text = ([string]$value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    return $text
}

# Pull the bare media type out of a Content-Type header. Tolerates the comma-
# joined form some servers emit when multiple Content-Type headers collapse
# (e.g., "text/html, text/html; charset=UTF-8") and strips parameters.
function Get-ResponseMediaType {
    param([AllowNull()][object]$Response)

    $ctRaw = Get-ResponseHeaderValue -Response $Response -Name "Content-Type"
    if ($null -eq $ctRaw) { return $null }

    return (($ctRaw -split ',')[0] -split ';')[0].Trim()
}

# Decide whether a media type is "text-like" enough for the link extractor
# to make sense of. A null/empty media type is treated as supported because
# many servers omit Content-Type on success and we do not want to discard
# valid HTML on that basis alone.
function Test-IsSupportedTextMediaType {
    param([AllowNull()][string]$MediaType)

    if ([string]::IsNullOrWhiteSpace($MediaType)) { return $true }
    return ($MediaType -match '(?i)text|html|json|xml|javascript')
}

function Get-ErrorResponse {
    param([AllowNull()][object]$ErrorObject)

    if ($null -eq $ErrorObject) { return $null }

    $ex = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        $ErrorObject.Exception
    }
    elseif ($ErrorObject.PSObject.Properties['Exception']) {
        $ErrorObject.Exception
    }
    else {
        $ErrorObject
    }

    while ($null -ne $ex) {
        try {
            $responseProp = $ex.PSObject.Properties['Response']
            if ($null -ne $responseProp -and $null -ne $responseProp.Value) {
                return $responseProp.Value
            }
        }
        catch { }

        $ex = $ex.InnerException
    }

    return $null
}

function Get-ResponseFinalUrl {
    param(
        [AllowNull()][object]$Response,
        [string]$FallbackUrl
    )

    if ($null -eq $Response) { return $FallbackUrl }

    try {
        $finalProp = $Response.PSObject.Properties['FindWebLinksFinalUrl']
        if ($null -ne $finalProp -and -not [string]::IsNullOrWhiteSpace([string]$finalProp.Value)) {
            return [string]$finalProp.Value
        }
    }
    catch { }

    try {
        $baseProp = $Response.PSObject.Properties['BaseResponse']
        if ($null -ne $baseProp -and $null -ne $baseProp.Value) {
            $base = $baseProp.Value

            try {
                $responseUriProp = $base.PSObject.Properties['ResponseUri']
                if ($null -ne $responseUriProp -and $null -ne $responseUriProp.Value) {
                    return $responseUriProp.Value.AbsoluteUri
                }
            }
            catch { }

            try {
                $requestMessageProp = $base.PSObject.Properties['RequestMessage']
                if ($null -ne $requestMessageProp -and $null -ne $requestMessageProp.Value -and $null -ne $requestMessageProp.Value.RequestUri) {
                    return $requestMessageProp.Value.RequestUri.AbsoluteUri
                }
            }
            catch { }
        }
    }
    catch { }

    return $FallbackUrl
}

function Get-ResponseContentText {
    param(
        [AllowNull()][object]$Response,
        [Parameter(Mandatory=$false)]
        [string]$Context = "web response"
    )

    if ($null -eq $Response) { return "" }

    try {
        $contentProp = $Response.PSObject.Properties['Content']
        if ($null -ne $contentProp) {
            return [string]$contentProp.Value
        }
    }
    catch {
        if (Test-IsInvalidWebRequestStateError $_) {
            throw "Could not read $Context content because the web response was already closed or cancelled. $($_.Exception.Message)"
        }
        throw
    }

    return ""
}

function Get-ResponseContentLengthSafe {
    param([AllowNull()][object]$Response)

    if ($null -eq $Response) { return -1 }

    try {
        return (Get-ResponseContentText -Response $Response -Context "response length check").Length
    }
    catch {
        return -1
    }
}


# ---------------------------------------------------------------------------
# robots.txt helpers
# ---------------------------------------------------------------------------
# robots.txt enforcement is opt-in. Enabling it by default would change the
# script's historical one-off extraction behaviour.
#
# This is a pragmatic RFC-style parser: User-agent groups, Allow, Disallow, '*'
# wildcards, '$' end anchors, longest-rule precedence, and Allow winning ties.
# Extensions such as Crawl-delay, Request-rate, and Sitemap are ignored; use
# -DelaySeconds and conservative crawl depth/page caps for politeness.
function Get-RobotsOriginKey {
    param([AllowNull()][string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }

    try {
        $uri = [uri]$Url
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notmatch '^(?i)https?$') { return $null }
        if ([string]::IsNullOrWhiteSpace($uri.Host)) { return $null }
        return $uri.GetLeftPart([System.UriPartial]::Authority).TrimEnd('/').ToLowerInvariant()
    }
    catch {
        return $null
    }
}

function Get-RobotsTxtUrlForUrl {
    param([AllowNull()][string]$Url)

    $origin = Get-RobotsOriginKey -Url $Url
    if (-not $origin) { return $null }
    return "$origin/robots.txt"
}

function Get-RobotsPathAndQuery {
    param([AllowNull()][string]$Url)

    try {
        $uri = [uri]$Url
        if (-not $uri.IsAbsoluteUri) { return "/" }
        if ([string]::IsNullOrWhiteSpace($uri.PathAndQuery)) { return "/" }
        return $uri.PathAndQuery
    }
    catch {
        return "/"
    }
}

function New-RobotsPathRule {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Disallow')]
        [string]$Directive,

        [AllowNull()]
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) { return $null }

    $specificityText = $Pattern.Trim()
    if ($specificityText.EndsWith('$')) {
        $specificityText = $specificityText.Substring(0, $specificityText.Length - 1)
    }

    return [pscustomobject]@{
        Directive   = $Directive
        Pattern     = $Pattern.Trim()
        Specificity = $specificityText.Replace('*', '').Length
    }
}

function Add-RobotsGroupIfPresent {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Groups,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Agents,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Rules
    )

    if ($Agents.Count -eq 0) { return }

    [void]$Groups.Add([pscustomobject]@{
        Agents = @($Agents.ToArray())
        Rules  = @($Rules.ToArray())
    })
}

function ConvertFrom-RobotsTxt {
    param([AllowNull()][string]$Text)

    $groups = [System.Collections.Generic.List[object]]::new()
    $agents = [System.Collections.Generic.List[string]]::new()
    $rules = [System.Collections.Generic.List[object]]::new()
    $seenRules = $false

    foreach ($rawLine in ([string]$Text -split "`r?`n")) {
        $line = if ($null -eq $rawLine) { "" } else { [string]$rawLine }
        $hashIndex = $line.IndexOf('#')
        if ($hashIndex -ge 0) { $line = $line.Substring(0, $hashIndex) }
        $line = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) {
            Add-RobotsGroupIfPresent -Groups $groups -Agents $agents -Rules $rules
            $agents = [System.Collections.Generic.List[string]]::new()
            $rules = [System.Collections.Generic.List[object]]::new()
            $seenRules = $false
            continue
        }

        if ($line -notmatch '^([^:]+):(.*)$') { continue }
        $field = $matches[1].Trim().ToLowerInvariant()
        $value = $matches[2].Trim()

        if ($field -eq 'user-agent') {
            if ($seenRules) {
                Add-RobotsGroupIfPresent -Groups $groups -Agents $agents -Rules $rules
                $agents = [System.Collections.Generic.List[string]]::new()
                $rules = [System.Collections.Generic.List[object]]::new()
                $seenRules = $false
            }
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$agents.Add($value.ToLowerInvariant())
            }
            continue
        }

        if ($field -eq 'allow' -or $field -eq 'disallow') {
            if ($agents.Count -eq 0) { continue }
            $seenRules = $true

            # Empty Disallow means "allow all" for that directive; empty Allow is
            # also a no-op for matching purposes.
            if ([string]::IsNullOrWhiteSpace($value)) { continue }

            $directive = if ($field -eq 'allow') { 'Allow' } else { 'Disallow' }
            $rule = New-RobotsPathRule -Directive $directive -Pattern $value
            if ($null -ne $rule) { [void]$rules.Add($rule) }
        }
    }

    Add-RobotsGroupIfPresent -Groups $groups -Agents $agents -Rules $rules
    return @($groups.ToArray())
}

function Test-RobotsAgentMatches {
    param(
        [AllowNull()][string]$RobotsUserAgentValue,
        [AllowNull()][string]$GroupAgent
    )

    if ([string]::IsNullOrWhiteSpace($GroupAgent)) { return $false }
    $agent = $GroupAgent.Trim().ToLowerInvariant()
    if ($agent -eq '*') { return $true }
    if ([string]::IsNullOrWhiteSpace($RobotsUserAgentValue)) { return $false }
    $robot = $RobotsUserAgentValue.Trim().ToLowerInvariant()

    # Match against the configured product token. StartsWith covers cases like
    # product token "Googlebot-News" matching a "googlebot" group.
    return $robot.StartsWith($agent, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-RobotsApplicableRules {
    param(
        [AllowNull()][object[]]$Groups,
        [AllowNull()][string]$RobotsUserAgentValue
    )

    $bestSpecificity = -1
    $matchingGroups = [System.Collections.Generic.List[object]]::new()

    foreach ($group in @($Groups)) {
        if ($null -eq $group) { continue }

        $groupSpecificity = -1
        foreach ($agent in @($group.Agents)) {
            if (Test-RobotsAgentMatches -RobotsUserAgentValue $RobotsUserAgentValue -GroupAgent $agent) {
                $agentText = ([string]$agent).Trim()
                $specificity = if ($agentText -eq '*') { 0 } else { $agentText.Length }
                if ($specificity -gt $groupSpecificity) { $groupSpecificity = $specificity }
            }
        }

        if ($groupSpecificity -lt 0) { continue }

        if ($groupSpecificity -gt $bestSpecificity) {
            $matchingGroups.Clear()
            $bestSpecificity = $groupSpecificity
        }

        if ($groupSpecificity -eq $bestSpecificity) {
            [void]$matchingGroups.Add($group)
        }
    }

    $rules = [System.Collections.Generic.List[object]]::new()
    foreach ($group in @($matchingGroups.ToArray())) {
        foreach ($rule in @($group.Rules)) {
            if ($null -ne $rule) { [void]$rules.Add($rule) }
        }
    }

    return @($rules.ToArray())
}

function Test-RobotsPathMatchesPattern {
    param(
        [Parameter(Mandatory = $true)][string]$PathAndQuery,
        [AllowNull()][string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) { return $false }

    $cleanPattern = $Pattern.Trim()
    $anchorToEnd = $cleanPattern.EndsWith('$')
    if ($anchorToEnd) {
        $cleanPattern = $cleanPattern.Substring(0, $cleanPattern.Length - 1)
    }
    if ([string]::IsNullOrWhiteSpace($cleanPattern)) { return $false }

    if ($cleanPattern.Contains('*')) {
        $regexText = '^' + ([regex]::Escape($cleanPattern) -replace '\\\*', '.*')
        if ($anchorToEnd) { $regexText += '$' }
        try {
            return [regex]::IsMatch($PathAndQuery, $regexText, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant, $Script:RegexTimeout)
        }
        catch {
            return $false
        }
    }

    if ($anchorToEnd) {
        return $PathAndQuery.Equals($cleanPattern, [System.StringComparison]::Ordinal)
    }

    return $PathAndQuery.StartsWith($cleanPattern, [System.StringComparison]::Ordinal)
}

function Test-RobotsPathAllowedByRules {
    param(
        [Parameter(Mandatory = $true)][string]$PathAndQuery,
        [AllowNull()][object[]]$Rules
    )

    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($rule in @($Rules)) {
        if ($null -eq $rule) { continue }
        if (Test-RobotsPathMatchesPattern -PathAndQuery $PathAndQuery -Pattern ([string]$rule.Pattern)) {
            [void]$matches.Add($rule)
        }
    }

    if ($matches.Count -eq 0) { return $true }

    $maxSpecificity = ($matches.ToArray() | ForEach-Object { [int]$_.Specificity } | Measure-Object -Maximum).Maximum
    $bestRules = @($matches.ToArray() | Where-Object { [int]$_.Specificity -eq [int]$maxSpecificity })

    # Allow wins ties.
    foreach ($rule in $bestRules) {
        if ([string]$rule.Directive -eq 'Allow') { return $true }
    }

    return $false
}

function New-RobotsPolicyObject {
    param(
        [Parameter(Mandatory = $true)][string]$OriginKey,
        [Parameter(Mandatory = $true)][string]$RobotsUrl,
        [Parameter(Mandatory = $true)][ValidateSet('ALLOW_ALL', 'RULES', 'UNAVAILABLE')][string]$Status,
        [AllowNull()][object[]]$Rules = @(),
        [AllowNull()][string]$Message = ""
    )

    return [pscustomobject]@{
        OriginKey = $OriginKey
        RobotsUrl = $RobotsUrl
        Status    = $Status
        Rules     = @($Rules)
        Message   = $Message
    }
}

function Get-RobotsHttpStatusFromErrorMessage {
    param([AllowNull()][string]$Message)

    if ([string]::IsNullOrWhiteSpace($Message)) { return $null }
    if ($Message -match '(?i)(HTTP|status code[^0-9]*:?\s*)\s*(?<code>\d{3})') {
        $code = 0
        if ([int]::TryParse($matches['code'].Value, [ref]$code)) { return $code }
    }

    return $null
}

function Get-RobotsPolicyForUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$RobotsUserAgentValue,
        [Parameter(Mandatory = $true)][int]$MaxRetries,
        [Parameter(Mandatory = $true)][int]$WaitSec,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [Parameter(Mandatory = $true)][string]$UserAgentString,
        [AllowNull()][string]$ProxyUrl,
        [Parameter(Mandatory = $true)][int]$MaxRedirectsCount,
        [Parameter(Mandatory = $true)][int]$MaxRetryAfterSecondsValue
    )

    $originKey = Get-RobotsOriginKey -Url $Url
    $robotsUrl = Get-RobotsTxtUrlForUrl -Url $Url

    if (-not $originKey -or -not $robotsUrl) {
        return (New-RobotsPolicyObject -OriginKey "" -RobotsUrl "" -Status "UNAVAILABLE" -Rules @() -Message "Could not determine robots.txt origin for URL: $Url")
    }

    if ($null -eq $Script:RobotsTxtCache) {
        $Script:RobotsTxtCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    $cached = $null
    if ($Script:RobotsTxtCache.TryGetValue($originKey, [ref]$cached)) {
        return $cached
    }

    $policy = $null
    $response = $null

    try {
        Write-Host "  robots.txt: checking $robotsUrl"

        $response = Invoke-WebRequestWithRetry `
            -Url $robotsUrl `
            -MaxRetries $MaxRetries `
            -WaitSec $WaitSec `
            -Timeout $TimeoutSec `
            -DoSecondFetch $false `
            -SecondWait 0 `
            -UserAgentString $UserAgentString `
            -ProxyUrl $ProxyUrl `
            -MaxRedirectsCount $MaxRedirectsCount `
            -MaxRetryAfterSecondsValue $MaxRetryAfterSecondsValue `
            -EnforceRobotsTxt $false `
            -RobotsUserAgentValue $RobotsUserAgentValue

        $robotsText = Get-ResponseContentText -Response $response -Context "robots.txt"
        if ($Script:MaxRobotsTxtBytes -gt 0) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($robotsText)
            if ($bytes.Length -gt $Script:MaxRobotsTxtBytes) {
                Write-Host "  robots.txt: larger than $([int]($Script:MaxRobotsTxtBytes / 1024)) KB; parsing only the first $([int]($Script:MaxRobotsTxtBytes / 1024)) KB."
                $robotsText = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $Script:MaxRobotsTxtBytes)
            }
        }

        $groups = @(ConvertFrom-RobotsTxt -Text $robotsText)
        $rules = @(Get-RobotsApplicableRules -Groups $groups -RobotsUserAgentValue $RobotsUserAgentValue)

        $policy = New-RobotsPolicyObject `
            -OriginKey $originKey `
            -RobotsUrl $robotsUrl `
            -Status "RULES" `
            -Rules $rules `
            -Message "Loaded $($rules.Count) applicable robots.txt rule(s) for User-agent '$RobotsUserAgentValue'."

        Write-Host "  robots.txt: loaded policy for $originKey ($($rules.Count) applicable rule(s))."
    }
    catch {
        if (Test-IsCancellationException $_) { throw }

        $message = $_.Exception.Message
        $status = Get-RobotsHttpStatusFromErrorMessage -Message $message

        if ($null -ne $status -and $status -ge 400 -and $status -lt 500) {
            # Missing/unavailable robots.txt due to 4xx is treated as no restrictions.
            $policy = New-RobotsPolicyObject `
                -OriginKey $originKey `
                -RobotsUrl $robotsUrl `
                -Status "ALLOW_ALL" `
                -Rules @() `
                -Message "robots.txt returned HTTP $status; treating as no robots.txt restrictions."
            Write-Host "  robots.txt: HTTP $status for $originKey; treating as no robots.txt restrictions."
        }
        else {
            # Fail closed on server/network/DNS errors while enforcement is explicitly enabled.
            $policy = New-RobotsPolicyObject `
                -OriginKey $originKey `
                -RobotsUrl $robotsUrl `
                -Status "UNAVAILABLE" `
                -Rules @() `
                -Message "robots.txt unavailable for ${originKey}: $message"
            Write-Host "  robots.txt: unavailable for $originKey; disallowing fetches for this origin while enforcement is enabled. $message"
        }
    }
    finally {
        if ($null -ne $response) { Close-BaseResponseSafe $response }
    }

    [void]$Script:RobotsTxtCache.TryAdd($originKey, $policy)
    return $policy
}

function Test-RobotsTxtAllowed {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$RobotsUserAgentValue,
        [Parameter(Mandatory = $true)][int]$MaxRetries,
        [Parameter(Mandatory = $true)][int]$WaitSec,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [Parameter(Mandatory = $true)][string]$UserAgentString,
        [AllowNull()][string]$ProxyUrl,
        [Parameter(Mandatory = $true)][int]$MaxRedirectsCount,
        [Parameter(Mandatory = $true)][int]$MaxRetryAfterSecondsValue
    )

    $normalizedUrl = ConvertTo-NormalizedLink -Link $Url
    if (-not $normalizedUrl) {
        return [pscustomobject]@{ Allowed = $false; Status = "INVALID"; Reason = "Invalid URL for robots.txt check: $Url" }
    }

    try {
        $uri = [uri]$normalizedUrl
        if ($uri.AbsolutePath -ieq '/robots.txt') {
            return [pscustomobject]@{ Allowed = $true; Status = "ALLOW_ALL"; Reason = "robots.txt itself is allowed" }
        }
    }
    catch { }

    $policy = Get-RobotsPolicyForUrl `
        -Url $normalizedUrl `
        -RobotsUserAgentValue $RobotsUserAgentValue `
        -MaxRetries $MaxRetries `
        -WaitSec $WaitSec `
        -TimeoutSec $TimeoutSec `
        -UserAgentString $UserAgentString `
        -ProxyUrl $ProxyUrl `
        -MaxRedirectsCount $MaxRedirectsCount `
        -MaxRetryAfterSecondsValue $MaxRetryAfterSecondsValue

    if ($policy.Status -eq "UNAVAILABLE") {
        return [pscustomobject]@{ Allowed = $false; Status = "UNAVAILABLE"; Reason = $policy.Message }
    }

    if ($policy.Status -eq "ALLOW_ALL") {
        return [pscustomobject]@{ Allowed = $true; Status = "ALLOW_ALL"; Reason = $policy.Message }
    }

    $pathAndQuery = Get-RobotsPathAndQuery -Url $normalizedUrl
    $allowed = Test-RobotsPathAllowedByRules -PathAndQuery $pathAndQuery -Rules $policy.Rules
    $reason = if ($allowed) { "Allowed by robots.txt for $pathAndQuery" } else { "Disallowed by robots.txt for $pathAndQuery" }

    return [pscustomobject]@{ Allowed = $allowed; Status = "RULES"; Reason = $reason }
}

function Assert-RobotsTxtAllowsUrl {
    param(
        [bool]$Enabled,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Purpose,
        [Parameter(Mandatory = $true)][string]$RobotsUserAgentValue,
        [Parameter(Mandatory = $true)][int]$MaxRetries,
        [Parameter(Mandatory = $true)][int]$WaitSec,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [Parameter(Mandatory = $true)][string]$UserAgentString,
        [AllowNull()][string]$ProxyUrl,
        [Parameter(Mandatory = $true)][int]$MaxRedirectsCount,
        [Parameter(Mandatory = $true)][int]$MaxRetryAfterSecondsValue
    )

    if (-not $Enabled) { return }

    $decision = Test-RobotsTxtAllowed `
        -Url $Url `
        -RobotsUserAgentValue $RobotsUserAgentValue `
        -MaxRetries $MaxRetries `
        -WaitSec $WaitSec `
        -TimeoutSec $TimeoutSec `
        -UserAgentString $UserAgentString `
        -ProxyUrl $ProxyUrl `
        -MaxRedirectsCount $MaxRedirectsCount `
        -MaxRetryAfterSecondsValue $MaxRetryAfterSecondsValue

    if ($decision.Allowed) { return }

    if ($decision.Status -eq "UNAVAILABLE") {
        throw "ROBOTS_TXT_UNAVAILABLE: $($decision.Reason)"
    }

    throw "ROBOTS_TXT_BLOCKED: robots.txt disallows ${Purpose}: $Url -- $($decision.Reason)"
}

function Test-IsRobotsTxtBlockedError {
    param([AllowNull()][object]$ErrorObject)

    $message = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { $ErrorObject.Exception.Message } else { [string]$ErrorObject }
    return ($message -match '^ROBOTS_TXT_BLOCKED:')
}

function Test-IsRobotsTxtUnavailableError {
    param([AllowNull()][object]$ErrorObject)

    $message = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { $ErrorObject.Exception.Message } else { [string]$ErrorObject }
    return ($message -match '^ROBOTS_TXT_UNAVAILABLE:')
}

# ---------------------------------------------------------------------------
# Function: Invoke-WebRequestWithRetry
# Purpose: The core HTTP engine. Handles resilient fetching, parsing timeouts, 
#          following redirects manually (to run SSRF checks on the target), 
#          and bypassing anti-bot measures through silent second fetching.
# ---------------------------------------------------------------------------
function Invoke-WebRequestWithRetry {
    param(
        [string]$Url,
        [int]$MaxRetries,
        [int]$WaitSec,
        [int]$Timeout,
        [bool]$DoSecondFetch,
        [int]$SecondWait,
        [string]$UserAgentString,
        [AllowNull()]
        [string]$ProxyUrl,
        [int]$MaxRedirectsCount,
        [int]$MaxRetryAfterSecondsValue,
        [bool]$EnforceRobotsTxt = $false,
        [string]$RobotsUserAgentValue = "AE-Find-WebLinks"
    )

    if ($Url -notmatch '^https?://') { $Url = "https://$Url" }

    $currentUrl = ConvertTo-NormalizedLink -Link $Url
    if (-not $currentUrl) {
        throw "Invalid URL: $Url"
    }

    # Use a persistent session to store cookies (crucial for sites requiring sessions)
    $session = New-FindWebLinksRequestSession

    $headers = @{
        "Accept"           = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        "Accept-Language"  = "en-GB,en;q=0.9"
        "Cache-Control"    = "no-cache"
    }

    $webRequestProxyParams = Get-FindWebLinksProxyParameters -ProxyUrl $ProxyUrl

    $maxRedirects = $MaxRedirectsCount
    $redirectsDone = 0
    $response = $null

    # Loop allows manual resolution of 3xx redirects
    :redirectLoop while ($true) {
        if (Test-IsPrivateUrl $currentUrl) {
            throw "SSRF Blocked: URL targets a private/internal network ($currentUrl)."
        }

        Assert-RobotsTxtAllowsUrl `
            -Enabled $EnforceRobotsTxt `
            -Url $currentUrl `
            -Purpose "fetching" `
            -RobotsUserAgentValue $RobotsUserAgentValue `
            -MaxRetries $MaxRetries `
            -WaitSec $WaitSec `
            -TimeoutSec $Timeout `
            -UserAgentString $UserAgentString `
            -ProxyUrl $ProxyUrl `
            -MaxRedirectsCount $MaxRedirectsCount `
            -MaxRetryAfterSecondsValue $MaxRetryAfterSecondsValue

        $lastError = $null

        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                Write-Host "  Attempt $attempt of $MaxRetries -- GET $currentUrl"

                # Disable automatic redirect following so every Location target can be
                # validated before another network request is made.
                $response = Invoke-WebRequest `
                    -Uri $currentUrl `
                    -WebSession $session `
                    -Headers $headers `
                    -UserAgent $UserAgentString `
                    -UseBasicParsing `
                    -MaximumRedirection 0 `
                    -TimeoutSec $Timeout `
                    -ErrorAction Stop `
                    @webRequestProxyParams

                $statusCode = Get-ResponseStatusCode -Response $response
                if ($null -ne $statusCode -and $statusCode -in @(301, 302, 303, 307, 308)) {
                    $rawLocation = Get-ResponseHeaderValue -Response $response -Name 'Location'
                    if (-not $rawLocation) {
                        Close-BaseResponseSafe $response
                        $response = $null
                        throw "HTTP redirect from $currentUrl did not include a Location header."
                    }

                    if ($redirectsDone -ge $maxRedirects) {
                        Close-BaseResponseSafe $response
                        $response = $null
                        throw "Too many HTTP redirects (max $maxRedirects). Last URL: $currentUrl"
                    }

                    $redirectUrl = ConvertTo-NormalizedLink -Link $rawLocation -BaseUri ([uri]$currentUrl)
                    if (-not $redirectUrl) {
                        Close-BaseResponseSafe $response
                        $response = $null
                        throw "Invalid HTTP redirect target from ${currentUrl}: $rawLocation"
                    }

                    if (Test-IsPrivateUrl $redirectUrl) {
                        Close-BaseResponseSafe $response
                        $response = $null
                        throw "SSRF Blocked: Redirect targets private/internal network ($redirectUrl)."
                    }

                    Write-Host "  Following HTTP redirect -> $redirectUrl"
                    Close-BaseResponseSafe $response
                    $response = $null
                    $currentUrl = $redirectUrl
                    $redirectsDone++
                    continue redirectLoop
                }

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
                            -UserAgent $UserAgentString `
                            -UseBasicParsing `
                            -MaximumRedirection 0 `
                            -TimeoutSec $Timeout `
                            -ErrorAction Stop `
                            @webRequestProxyParams

                        $statusCode2 = Get-ResponseStatusCode -Response $response2
                        if ($null -ne $statusCode2 -and $statusCode2 -in @(301, 302, 303, 307, 308)) {
                            # Do not let the silent second fetch follow a new redirect invisibly.
                            # The first successful response remains the source of truth.
                        }
                        elseif ((Get-ResponseContentLengthSafe -Response $response2) -gt (Get-ResponseContentLengthSafe -Response $response)) {
                            # A larger second response only earns the swap if its
                            # media type is also text-like. Otherwise a cookie-
                            # walled HTML first response can be silently displaced
                            # by a binary second response (PDF, image, tracking
                            # blob), which the link extractor cannot read.
                            $mediaType2 = Get-ResponseMediaType -Response $response2
                            if (Test-IsSupportedTextMediaType -MediaType $mediaType2) {
                                Close-BaseResponseSafe $response
                                $response = $response2
                                $keepResponse2 = $true
                            }
                        }
                    }
                    catch {
                        if (Test-IsCancellationException $_) { throw }

                        # Second fetch failed silently -- use first response.
                        $excResponse = Get-ErrorResponse $_
                        if ($null -ne $excResponse) {
                            Close-BaseResponseSafe $excResponse
                        }
                    }
                    finally {
                        # Dispose $response2 if it was not promoted to $response.
                        if (-not $keepResponse2 -and $null -ne $response2) {
                            Close-BaseResponseSafe $response2
                        }
                    }
                }

                # Check for <meta http-equiv="refresh"> redirect (quoted or unquoted).
                $responseTextForMetaRefresh = Get-ResponseContentText -Response $response -Context "meta-refresh scan"
                $metaRefresh = Get-RegexFirstMatchSafe -Regex $global:RegexMetaRefresh -InputText $responseTextForMetaRefresh -Name "meta-refresh redirect"
                if ($null -ne $metaRefresh -and $metaRefresh.Success) {
                    $nextUrl = $metaRefresh.Groups["url"].Value.Trim()
                    $nextUrl = ConvertTo-NormalizedLink -Link $nextUrl -BaseUri ([uri]$currentUrl)
                    if ($nextUrl -and $nextUrl -ne $currentUrl) {
                        if ($redirectsDone -ge $maxRedirects) {
                            Close-BaseResponseSafe $response
                            $response = $null
                            throw "Too many meta-refresh redirects (max $maxRedirects). Last URL: $currentUrl"
                        }

                        if (Test-IsPrivateUrl $nextUrl) {
                            Close-BaseResponseSafe $response
                            $response = $null
                            throw "SSRF Blocked: Meta-refresh redirect targets private/internal network ($nextUrl)."
                        }

                        Write-Host "  Following meta-refresh redirect -> $nextUrl"
                        Close-BaseResponseSafe $response
                        $response = $null
                        $currentUrl = $nextUrl
                        $redirectsDone++
                        continue redirectLoop
                    }
                }

                try {
                    Add-Member -InputObject $response -NotePropertyName FindWebLinksFinalUrl -NotePropertyValue $currentUrl -Force
                }
                catch { }

                return $response
            }
            catch {
                if (Test-IsCancellationException $_) {
                    if ($null -ne $response) {
                        Close-BaseResponseSafe $response
                        $response = $null
                    }
                    throw
                }

                $attemptErrorMessage = $_.Exception.Message
                if ($attemptErrorMessage -match '^(SSRF Blocked:|ROBOTS_TXT_BLOCKED:|ROBOTS_TXT_UNAVAILABLE:|Too many HTTP redirects|Too many meta-refresh redirects|Invalid HTTP redirect target|HTTP redirect .* did not include a Location header|Invalid URL:)') {
                    if ($null -ne $response) {
                        Close-BaseResponseSafe $response
                        $response = $null
                    }
                    throw
                }

                $lastError = $_
                Write-Host "  Attempt $attempt failed: $attemptErrorMessage"

                if ($null -ne $response) {
                    Close-BaseResponseSafe $response
                    $response = $null
                }

                # PowerShell 5.1's Invoke-WebRequest throws InvalidOperationException
                # with FQEID "MaximumRedirectExceeded" when a 3xx response is returned
                # under -MaximumRedirection 0, and crucially does NOT attach the
                # response to the exception. That means $_.Exception.Response is
                # $null, Get-ErrorResponse returns $null, and the script's regular
                # 3xx-handling branch below never runs -- so the script retries the
                # same URL forever. Detect this case by FQEID (which IS reliable
                # across PS versions) and recover the redirect target with a raw
                # HttpWebRequest. SSRF validation runs on the recovered target
                # exactly as it does on the normal redirect path.
                if ($_.FullyQualifiedErrorId -like 'MaximumRedirectExceeded*') {
                    $fallback = $null
                    try {
                        $fallback = Get-RedirectTargetViaRawRequest `
                            -Url $currentUrl `
                            -UserAgent $UserAgentString `
                            -Headers $headers `
                            -Session $session `
                            -TimeoutSec $Timeout `
                            -ProxyUrl $ProxyUrl
                    }
                    catch {
                        # Fallback itself failed (network error, DNS, etc.).
                        # Fall through to normal retry rather than getting stuck.
                        Write-Host "  Could not recover redirect target via fallback: $($_.Exception.Message)"
                    }

                    if ($null -ne $fallback `
                        -and $null -ne $fallback.Location `
                        -and $fallback.StatusCode -in @(301, 302, 303, 307, 308)) {

                        if ($redirectsDone -ge $maxRedirects) {
                            throw "Too many HTTP redirects (max $maxRedirects). Last URL: $currentUrl"
                        }

                        $rawLocation = [string]$fallback.Location
                        $redirectUrl = ConvertTo-NormalizedLink -Link $rawLocation -BaseUri ([uri]$currentUrl)
                        if (-not $redirectUrl) {
                            throw "Invalid HTTP redirect target from ${currentUrl}: $rawLocation"
                        }

                        if (Test-IsPrivateUrl $redirectUrl) {
                            throw "SSRF Blocked: Redirect targets private/internal network ($redirectUrl)."
                        }

                        Write-Host "  Following HTTP redirect -> $redirectUrl"
                        $currentUrl = $redirectUrl
                        $redirectsDone++
                        continue redirectLoop
                    }
                    # Fallback didn't yield a usable redirect; fall through to
                    # normal retry path below.
                }

                if (Test-IsInvalidWebRequestStateError $_) {
                    # A Ctrl+C/interrupted HTTP request or a fragile redirect response can leave
                    # the web cmdlet/session in a bad state. Do not keep reusing that state.
                    $session = New-FindWebLinksRequestSession
                }

                $responseObj = Get-ErrorResponse $_

                if ($null -ne $responseObj) {
                    $statusCode = Get-ResponseStatusCode -Response $responseObj

                    if ($null -ne $statusCode) {
                        # Fail permanently on hard blocks
                        if ($statusCode -in @(401, 403, 404, 410)) {
                            Close-BaseResponseSafe $responseObj
                            throw "Permanent HTTP $statusCode error. Aborting retries for $currentUrl."
                        }

                        if ($statusCode -in @(301, 302, 303, 307, 308)) {
                            $rawLocation = Get-ResponseHeaderValue -Response $responseObj -Name 'Location'
                            if ($rawLocation) {
                                if ($redirectsDone -ge $maxRedirects) {
                                    Close-BaseResponseSafe $responseObj
                                    throw "Too many HTTP redirects (max $maxRedirects). Last URL: $currentUrl"
                                }

                                $redirectUrl = ConvertTo-NormalizedLink -Link $rawLocation -BaseUri ([uri]$currentUrl)
                                if (-not $redirectUrl) {
                                    Close-BaseResponseSafe $responseObj
                                    throw "Invalid HTTP redirect target from ${currentUrl}: $rawLocation"
                                }

                                if (Test-IsPrivateUrl $redirectUrl) {
                                    Close-BaseResponseSafe $responseObj
                                    throw "SSRF Blocked: Redirect targets private/internal network ($redirectUrl)."
                                }

                                Write-Host "  Following HTTP redirect -> $redirectUrl"
                                Close-BaseResponseSafe $responseObj
                                $currentUrl = $redirectUrl
                                $redirectsDone++
                                continue redirectLoop
                            }
                        }

                        # #2: Honour Retry-After header for 429/503.
                        if ($statusCode -in @(429, 503)) {
                            $raVal = Get-ResponseHeaderValue -Response $responseObj -Name 'Retry-After'
                            if ($null -ne $raVal) {
                                $raSec = 0
                                if ([int]::TryParse(([string]$raVal).Trim(), [ref]$raSec) -and $raSec -gt 0) {
                                    if ($MaxRetryAfterSecondsValue -eq 0) {
                                        Write-Host "  Server requested Retry-After: $raSec second(s); ignoring because -MaxRetryAfterSeconds is 0 and using the normal retry delay."
                                    }
                                    elseif ($raSec -le $MaxRetryAfterSecondsValue) {
                                        Write-Host "  Server requested Retry-After: $raSec second(s)"
                                        Close-BaseResponseSafe $responseObj
                                        Start-Sleep -Seconds $raSec
                                        continue
                                    }
                                }
                                else {
                                    try {
                                        $retryAfterDate = [datetime]::Parse([string]$raVal).ToUniversalTime()
                                        $deltaSeconds = [int][Math]::Ceiling(($retryAfterDate - (Get-Date).ToUniversalTime()).TotalSeconds)
                                        if ($deltaSeconds -gt 0 -and $MaxRetryAfterSecondsValue -gt 0 -and $deltaSeconds -le $MaxRetryAfterSecondsValue) {
                                            Write-Host "  Server requested Retry-After date; waiting $deltaSeconds second(s)"
                                            Close-BaseResponseSafe $responseObj
                                            Start-Sleep -Seconds $deltaSeconds
                                            continue
                                        }
                                    }
                                    catch { }
                                }
                            }
                        }
                    }

                    Close-BaseResponseSafe $responseObj
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

        $lastMessage = if ($null -ne $lastError) { $lastError.Exception.Message } else { "Unknown error" }
        throw "All $MaxRetries attempt(s) failed for $currentUrl. Last error: $lastMessage"
    }
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
    param(
        [string]$PageUrl,
        [int]$MaxRetries,
        [int]$WaitSec,
        [int]$TimeoutSec,
        [bool]$DoSecondFetch,
        [int]$SecondWaitSec,
        [string]$UserAgentString,
        [AllowNull()]
        [string]$ProxyUrl,
        [int]$MaxRedirectsCount,
        [int]$MaxRetryAfterSecondsValue,
        [bool]$EnforceRobotsTxt = $false,
        [string]$RobotsUserAgentValue = "AE-Find-WebLinks",
        [int64]$MaxPageContentBytesValue,
        [int]$MaxPageContentMBValue
    )

    if ($PageUrl -notmatch '^https?://') { $PageUrl = "https://$PageUrl" }

    $response = $null

    try {
        $response = Invoke-WebRequestWithRetry `
            -Url $PageUrl `
            -MaxRetries $MaxRetries `
            -WaitSec $WaitSec `
            -Timeout $TimeoutSec `
            -DoSecondFetch $DoSecondFetch `
            -SecondWait $SecondWaitSec `
            -UserAgentString $UserAgentString `
            -ProxyUrl $ProxyUrl `
            -MaxRedirectsCount $MaxRedirectsCount `
            -MaxRetryAfterSecondsValue $MaxRetryAfterSecondsValue `
            -EnforceRobotsTxt $EnforceRobotsTxt `
            -RobotsUserAgentValue $RobotsUserAgentValue

        # Force Content-Type to scalar and split comma-separated values.
        $contentType = Get-ResponseMediaType -Response $response
        if (-not (Test-IsSupportedTextMediaType -MediaType $contentType)) {
            Write-Host "  Skipping binary or unsupported content type: $contentType"
            return @()
        }

        # Content-Length is only a hint because Invoke-WebRequest has already loaded
        # the body, but it still avoids expensive parsing/regex work on huge responses.
        $clRaw = Get-ResponseHeaderValue -Response $response -Name "Content-Length"
        if ($null -ne $clRaw) {
            $clValue = 0L
            if ([long]::TryParse(([string]$clRaw).Trim(), [ref]$clValue) -and $MaxPageContentBytesValue -gt 0 -and $clValue -gt $MaxPageContentBytesValue) {
                Write-Host "  Skipping: response exceeds $($MaxPageContentMBValue) MB ($clValue bytes). Use -MaxPageContentMB 0 to disable this guard."
                return @()
            }
        }

        $html = Get-ResponseContentText -Response $response -Context "page body"

        # Additional size guard after content is loaded. String.Length is UTF-16
        # code units, not bytes, so compare the configured byte limit to an
        # encoded byte count rather than to character count.
        if ($MaxPageContentBytesValue -gt 0) {
            $htmlByteCount = [System.Text.Encoding]::UTF8.GetByteCount($html)
            if ($htmlByteCount -gt $MaxPageContentBytesValue) {
                Write-Host "  Skipping: page content exceeds $($MaxPageContentMBValue) MB ($htmlByteCount UTF-8 bytes, $($html.Length) characters). Use -MaxPageContentMB 0 to disable this guard."
                return @()
            }
        }

        # Detect empty body. This is most often a WAF block or a 204/205-style
        # success that intentionally has no payload; report what the server
        # actually said rather than assuming 200 OK.
        if ($html.Length -eq 0) {
            $emptyBodyStatus = Get-ResponseStatusCode -Response $response
            $emptyBodyDescription = if ($null -ne $emptyBodyStatus) { "HTTP $emptyBodyStatus" } else { "an unknown status" }
            Write-Host "  WARNING: Server returned $emptyBodyDescription with an empty body (possible WAF block, 204 No Content, etc.)."
            return @()
        }

        Write-Host "  Page content length: $($html.Length) characters"

        # Resolve base URI from the final response URL after redirects.
        $finalUrl = Get-ResponseFinalUrl -Response $response -FallbackUrl $PageUrl
        $baseUri = [uri]$finalUrl

        # SSRF check: ensure redirects didn't land on a private/internal IP
        if (Test-IsPrivateUrl $finalUrl) {
            Write-Host "  BLOCKED: Redirect landed on private/internal URL: $finalUrl"
            return @()
        }

        # Honour <base href="..."> if the page declares one (quoted or unquoted).
        $baseTag = Get-RegexFirstMatchSafe -Regex $global:RegexBaseHref -InputText $html -Name "base href"
        if ($null -ne $baseTag -and $baseTag.Success) {
            $baseHref = ConvertTo-NormalizedLink -Link $baseTag.Groups["href"].Value -BaseUri $baseUri
            if ($baseHref) {
                $baseUri = [uri]$baseHref
                Write-Host "  Using <base href>: $baseHref"
            }
        }

        # Use List[string] so -KeepDuplicates is not silently broken.
        $found = New-Object System.Collections.Generic.List[string]

        # #11: Strip HTML comments to avoid extracting dead/commented-out links.
        # Use StringBuilder for a single O(n) pass instead of repeated String.Remove
        # calls, which copy the entire remaining buffer per iteration and are O(n*m)
        # for m comments. On a 5 MB page with thousands of comments the old approach
        # could allocate gigabytes of intermediate strings and stall on GC.
        # Behaviour preserved: an unclosed "<!--" with no matching "-->" stops the
        # comment scan and leaves the unclosed marker plus all trailing content in
        # the cleaned HTML, matching the previous loop.
        if ($html.IndexOf("<!--") -ge 0) {
            $sb = [System.Text.StringBuilder]::new($html.Length)
            $cursor = 0
            while ($true) {
                $commentStart = $html.IndexOf("<!--", $cursor)
                if ($commentStart -lt 0) { break }
                $commentEnd = $html.IndexOf("-->", $commentStart)
                if ($commentEnd -lt 0) { break }   # Unclosed comment -- leave remainder in place

                # Append safe text before this comment, then jump past the comment.
                [void]$sb.Append($html, $cursor, $commentStart - $cursor)
                $cursor = $commentEnd + 3
            }

            if ($cursor -lt $html.Length) {
                [void]$sb.Append($html, $cursor, $html.Length - $cursor)
            }

            $htmlClean = $sb.ToString()
        }
        else {
            $htmlClean = $html
        }

        # #12: Extract OpenGraph, Twitter Card, and other meta content URLs
        foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexMetaContentUrl -InputText $htmlClean -Name "meta content URLs")) {
            $found.Add($m.Groups["url"].Value)
        }

        # #17: Extract @import url() from <style> blocks
        foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexStyleImport -InputText $htmlClean -Name "style imports")) {
            $val = $m.Groups["url"].Value
            if (-not $val.StartsWith("data:", [System.StringComparison]::OrdinalIgnoreCase)) {
                $found.Add($val)
            }
        }

        # ----- 1. Quoted HTML attributes: href, src, action, data-*, etc. -----
        foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexAttr -InputText $htmlClean -Name "quoted HTML attributes")) {
            $attrName = $m.Groups["attr"].Value
            Add-FoundLinkCandidate -List $found -Value $m.Groups["url"].Value -Srcset:($attrName -ieq "srcset")
        }

        # Unquoted HTML attributes (e.g. href=https://example.com)
        foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexUnquotedAttr -InputText $htmlClean -Name "unquoted HTML attributes")) {
            $attrName = $m.Groups["attr"].Value
            Add-FoundLinkCandidate -List $found -Value $m.Groups["url"].Value -Srcset:($attrName -ieq "srcset")
        }

        # ----- 2. Raw absolute / protocol-relative / bare URLs anywhere -------
        foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexRawUrl -InputText $htmlClean -Name "raw URLs")) {
            $found.Add($m.Value)
        }

        # ----- 3. URLs inside <script> blocks (JSON, JS assignments, etc.) ----
        foreach ($scriptMatch in (Get-RegexMatchesSafe -Regex $global:RegexScript -InputText $htmlClean -Name "script blocks")) {
            $body = $scriptMatch.Groups["body"].Value

            # Quoted strings that look like URLs
            foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexJsUrl -InputText $body -Name "JavaScript URLs")) {
                $raw = ConvertFrom-JsUrl $m.Groups["url"].Value
                # Strip ES6 template literal interpolation markers
                $raw = $raw -replace '\$\{[^}]*\}', ''
                if ($raw -and $raw.Length -gt 4) { $found.Add($raw) }
            }

            # JSON-style "key": "/path/..." or "key": "https://..."
            foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexJsonPath -InputText $body -Name "JSON paths")) {
                $found.Add((ConvertFrom-JsUrl $m.Groups["url"].Value))
            }
        }

        # ----- 4. <noscript> blocks (fallback content for no-JS) --------------
        foreach ($nsMatch in (Get-RegexMatchesSafe -Regex $global:RegexNoscript -InputText $htmlClean -Name "noscript blocks")) {
            $nsBody = $nsMatch.Groups["body"].Value
            foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexAttr -InputText $nsBody -Name "noscript quoted attributes")) {
                $attrName = $m.Groups["attr"].Value
                Add-FoundLinkCandidate -List $found -Value $m.Groups["url"].Value -Srcset:($attrName -ieq "srcset")
            }
            foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexUnquotedAttr -InputText $nsBody -Name "noscript unquoted attributes")) {
                $attrName = $m.Groups["attr"].Value
                Add-FoundLinkCandidate -List $found -Value $m.Groups["url"].Value -Srcset:($attrName -ieq "srcset")
            }
        }

        # ----- 5. CSS url() references ----------------------------------------
        foreach ($m in (Get-RegexMatchesSafe -Regex $global:RegexCssUrl -InputText $htmlClean -Name "CSS url() references")) {
            $val = $m.Groups["url"].Value
            # Skip data: URIs early to avoid wasting cycles on base64 blobs
            if (-not $val.StartsWith("data:", [System.StringComparison]::OrdinalIgnoreCase)) {
                $found.Add($val)
            }
        }

        # Normalize everything and remove failed normalisations
        return @(
            @($found).ForEach({ ConvertTo-NormalizedLink -Link $_ -BaseUri $baseUri }).Where({ $_ })
        )
    }
    finally {
        # Dispose network streams to prevent resource leaks on long runs
        Close-BaseResponseSafe $response
    }
}

# ---------------------------------------------------------------------------
# REGEX DEFINITIONS
# Pre-compiled regexes for link extraction (compiled once, used per page)
# ---------------------------------------------------------------------------
$global:CompiledRegexOptions = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::ExplicitCapture
$global:RegexTimeout = $Script:RegexTimeout

# Matches standard attributes like href="", src="", data-url=""
$global:RegexAttr = [regex]::new(
    '\b(?<attr>href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*["''](?<url>[^"'']+)["'']',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

# Matches unquoted attributes like href=https://example.com
$global:RegexUnquotedAttr = [regex]::new(
    '\b(?<attr>href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*(?<url>[^\s"''>]+)',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

# Matches raw absolute URLs explicitly written in the HTML body
$global:RegexRawUrl = [regex]::new(
    # The body of each domain alternative uses [a-z0-9.-]* (zero or more)
    # rather than + so that single-letter first labels like t.co, g.co, and
    # j.mp are extracted from raw text. The negative lookbehind on the last
    # alternative still prevents matches inside paths and word-like contexts.
    '(?x)
    (?:
        https?://[^\s<>"''\)\]\}]+
      | //[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(?::\d+)?(?:[/?#][^\s<>"''\)\]\}]*)?
      | www\.[^\s<>"''\)\]\}]+
      | (?<![@/\w.-])[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(?::\d+)?(?:[/?#][^\s<>"''\)\]\}]*)?
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
    '(?:"|''|`)(?<url>(?:https?:)?(?:\\?/){2}[^"''`\s]{5,})(?:"|''|`)',
    $global:CompiledRegexOptions, $global:RegexTimeout
)

$global:RegexJsonPath = [regex]::new(
    '"[^"]*"\s*:\s*"(?<url>\\?/[^"]{2,}|https?:\\?/\\?/[^"]+)"',
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

$global:RegexMetaRefresh = [regex]::new(
    '<meta\b(?=[^>]*http-equiv\s*=\s*["'']?refresh["'']?)(?=[^>]*content\s*=\s*["'']?\s*\d+\s*;\s*url\s*=\s*["'']*(?<url>[^"''\s>]+))[^>]*>',
    $global:CompiledRegexOptions -bor [System.Text.RegularExpressions.RegexOptions]::Singleline,
    $global:RegexTimeout
)

$global:RegexBaseHref = [regex]::new(
    '<base[^>]+href\s*=\s*(?:["''](?<href>[^"'']+)["'']|(?<href>[^\s"''>]+))',
    $global:CompiledRegexOptions,
    $global:RegexTimeout
)

$global:RegexMetaContentUrl = [regex]::new(
    '<meta[^>]+content\s*=\s*["''](?<url>https?://[^"'']+)["'']',
    $global:CompiledRegexOptions,
    $global:RegexTimeout
)

$global:RegexStyleImport = [regex]::new(
    '@import\s+(?:url\()?\s*["'']?(?<url>[^"''\)\s;]+)["'']?\s*\)?',
    $global:CompiledRegexOptions,
    $global:RegexTimeout
)

# ---------------------------------------------------------------------------
# MAIN EXECUTION AND FILTER PIPELINE
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
        $BlacklistSet,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Input", "Output", "Both")]
        [string]$BlacklistScope,
        [bool]$KeepDuplicates = $false,
        [bool]$NoDuplicates = $true,
        [bool]$KeepFragments = $false,
        [bool]$UseEvaluationValue = $false
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
        Test-LinkMatchesSearch -Link $_ -RegexList $RegexList -Mode $SearchMode -UseEvaluationValue $UseEvaluationValue
    }))

    $stats.Matched = $matched.Count
    if ($matched.Count -eq 0) { return $stats }

    # Remove links matching exclusion pattern(s), if supplied
    if ($null -ne $ExcludeRegexList -and $ExcludeRegexList.Count -gt 0) {
        $beforeExclude = $matched.Count
        $matched = @($matched.Where({
            -not (Test-LinkMatchesExclude -Link $_ -RegexList $ExcludeRegexList -Mode $ExcludeMode -UseEvaluationValue $UseEvaluationValue)
        }))
        $stats.Excluded = $beforeExclude - $matched.Count
    }

    if ($matched.Count -eq 0) { return $stats }

    # Remove duplicates within this batch unless told otherwise. Use the same
    # normalised key as output/progress deduplication so http/https, trailing
    # slash, and fragment policy behave consistently.
    if (-not $KeepDuplicates) {
        $beforeBatchDedup = $matched.Count
        $seenInBatch = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $dedupedMatched = New-Object System.Collections.Generic.List[string]

        foreach ($link in $matched) {
            $key = Get-LinkKey -Link $link -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue
            if ($seenInBatch.Add($key)) {
                $dedupedMatched.Add($link)
            }
        }

        $matched = @($dedupedMatched)
        $stats.Duplicates += ($beforeBatchDedup - $matched.Count)
    }

    # Skip blacklisted links (only when scope is Output or Both)
    if ((Test-BlacklistAppliesToOutput -Scope $BlacklistScope) -and $null -ne $BlacklistSet -and $BlacklistSet.Count -gt 0) {
        $beforeBl = $matched.Count
        $matched = @($matched.Where({
            -not (Test-IsBlacklisted -Url $_ -BlacklistSet $BlacklistSet -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue)
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
                $key = Get-LinkKey -Link $link -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue

                # Keep duplicates from this page, but still skip links already
                # present in the existing output file or written by previous pages.
                if (-not $WrittenSet.ContainsKey($key)) {
                    $toWriteList.Add((Get-LinkWriteValue -Link $link -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue))
                }
            }
        }
        else {
            $seenThisBatch = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )

            foreach ($link in $matched) {
                $key = Get-LinkKey -Link $link -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue

                if (
                    -not $WrittenSet.ContainsKey($key) -and
                    $seenThisBatch.Add($key)
                ) {
                    $toWriteList.Add((Get-LinkWriteValue -Link $link -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue))
                }
            }
        }

        $toWrite = @($toWriteList)
        $stats.Duplicates += ($beforeDedup - $toWrite.Count)
    }
    else {
        $toWrite = @(@($matched).ForEach({ Get-LinkWriteValue -Link $_ -KeepFragments $KeepFragments -UseEvaluationValue $UseEvaluationValue }))
    }

    if ($toWrite.Count -eq 0) { return $stats }

    # Write and track. Output writes are fatal: continuing after losing
    # matched links would make resume/logging claim work was done when it was not.
    $safeOutFile = Get-SafeAbsolutePath $OutFile
    try {
        Write-FileLinesWithRetry -FilePath $safeOutFile -Lines ([string[]]$toWrite)
    }
    catch {
        throw "Output write failed for ${safeOutFile}: $($_.Exception.Message)"
    }

    if ($NoDuplicates) {
        foreach ($link in $toWrite) {
            # $toWrite already contains the evaluated/write value, so do not
            # apply the evaluation regex again when updating the written set.
            [void]$WrittenSet.TryAdd((Get-LinkKey -Link $link -KeepFragments $KeepFragments), [byte]0)
        }
    }

    $stats.Written = $toWrite.Count
    return $stats
}

# ==============================================================================
# SCRIPT KICKOFF & MAIN TRY-CATCH BLOCK
# ==============================================================================
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
                Invoke-FileMaintenance -FilePath $Files -Deduplicate:$true -Sort:$false -SortDirection $SortDirection -KeepFragments $KeepFragments
            }
            "Sort" {
                Write-Host "--- Maintenance command: Sort ($SortDirection) ---"
                Invoke-FileMaintenance -FilePath $Files -Deduplicate:$false -Sort:$true -SortDirection $SortDirection -KeepFragments $KeepFragments
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
                    -SortDirection $SortDirection `
                    -KeepFragments $KeepFragments
            }
        }

        Write-Host "--- Maintenance complete. No URLs were fetched. ---"
        exit 0
    }

    if ($Files -and $Files.Count -gt 0) {
        Write-Warning "-Files is ignored when -Command Run is used. Use -Command Deduplicate, Sort, or Maintain for standalone maintenance, or use -DeduplicateWhen/-SortWhen to maintain Source/OutputFile/BlacklistFile during a normal run."
    }

    # Force append if we are resuming to prevent data loss 
    if ($Resume -and ($Mode -eq "New" -or $LogMode -eq "New" -or $FailedUrlMode -eq "New")) {
        Write-Host "Resume mode forces all output modes from New to Append to prevent data loss."
        $Mode = "Append"
        $LogMode = "Append"
        $FailedUrlMode = "Append"
    }

    if ($Resume -and $SourceType -ne "File") {
        throw "-Resume is only useful with SourceType File."
    }

    if ($Script:CrawlEnabled -and $Resume) {
        throw "-Resume is not supported when crawl mode is enabled. A crawl needs to persist its frontier, not just completed source URLs. Re-run without -Resume, or use -FollowDepth 0 for resumable file-list processing."
    }

    if ($Script:CrawlEnabled -and $ThrottleLimit -gt 1) {
        throw "Crawl mode currently requires -ThrottleLimit 1. Dynamic crawl frontiers are processed sequentially to keep depth, deduplication, and output writes deterministic."
    }

    if ((-not $Script:CrawlEnabled) -and $FollowPathScope -ne "Any") {
        Write-Warning "-FollowPathScope is ignored when crawl mode is disabled (-FollowDepth 0)."
    }

    if ($EnforceRobotsTxt) {
        if ([string]::IsNullOrWhiteSpace($RobotsUserAgent)) {
            throw "-RobotsUserAgent cannot be empty when -EnforceRobotsTxt is used. Use a product token such as AE-Find-WebLinks."
        }
        $RobotsUserAgent = $RobotsUserAgent.Trim()

        if ($ThrottleLimit -gt 1) {
            throw "-EnforceRobotsTxt currently requires -ThrottleLimit 1. robots.txt decisions are cached and applied deterministically only in sequential mode."
        }
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
    # Crawl mode does not support resume/frontier persistence yet, so do not
    # create or require a progress file only when crawl mode is disabled.
    if ($SourceType -eq "File" -and (-not $Script:CrawlEnabled) -and [string]::IsNullOrWhiteSpace($ProgressFile)) {
        $ProgressFile = "$OutputFile.progress"
    }

    # Refuse to start a fresh File-mode run when an old progress file exists.
    # This must happen before output/log files are created or overwritten.
    if (
        $SourceType -eq "File" -and
        (-not $Script:CrawlEnabled) -and
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
    if ($ProgressFile -and -not (Test-ValidFilePath $ProgressFile)) {
        throw "Progress file path contains illegal characters: $ProgressFile"
    }
    if ($BlacklistFile) {
        foreach ($blPathToValidate in $BlacklistFile) {
            if ([string]::IsNullOrWhiteSpace($blPathToValidate)) { continue }
            if (-not (Test-ValidFilePath $blPathToValidate)) {
                throw "Blacklist file path contains illegal characters: $blPathToValidate"
            }
        }
    }

    # Validate existing path types before creating/truncating any output/log files.
    # This prevents accidental data loss when Mode=New is used with a bad source
    # path, or when a log/output argument points to a directory.
    if ($SourceType -eq "File") {
        if (-not (Test-ValidFilePath $Source)) {
            throw "Input file path contains illegal characters: $Source"
        }

        $sourceForExistenceCheck = Get-SafeAbsolutePath $Source
        if (-not [System.IO.File]::Exists($sourceForExistenceCheck)) {
            throw "Input file does not exist or is not a file: $Source"
        }

        $sourceProbe = $null
        try {
            $sourceProbe = [System.IO.FileStream]::new(
                $sourceForExistenceCheck,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite
            )
        }
        catch {
            throw "Input file exists but cannot be opened for reading: $Source. $($_.Exception.Message)"
        }
        finally {
            if ($null -ne $sourceProbe) { $sourceProbe.Dispose() }
        }
    }

    foreach ($pathCheck in @(
        [pscustomobject]@{ Name = "Output file"; Path = $OutputFile },
        [pscustomobject]@{ Name = "Log CSV file"; Path = $LogCsv },
        [pscustomobject]@{ Name = "Failed URL file"; Path = $FailedUrlFile },
        [pscustomobject]@{ Name = "Progress file"; Path = $ProgressFile }
    )) {
        if (-not [string]::IsNullOrWhiteSpace($pathCheck.Path)) {
            $safeExistingPath = Get-SafeAbsolutePath $pathCheck.Path
            if ([System.IO.Directory]::Exists($safeExistingPath)) {
                throw "$($pathCheck.Name) points to a directory, not a file: $($pathCheck.Path)"
            }
        }
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


    if (
        $Resume -and
        $SourceType -eq "File" -and
        $ProgressFile -and
        (Test-Path -LiteralPath $ProgressFile) -and
        -not (Test-Path -LiteralPath $OutputFile)
    ) {
        throw "Resume progress exists but the output file is missing: $OutputFile. Refusing to continue because completed source URLs would be skipped and their previous matches could be lost. Restore the output file, delete the progress file to restart, or use a different -ProgressFile."
    }

    # Validate a single URL source before creating or truncating any output/log files.
    # In older versions, Mode=New could wipe the output and only then fail on a bad URL.
    $validatedSingleSourceUrl = $null
    if ($SourceType -eq "Url") {
        $validatedSingleSourceUrl = ConvertTo-NormalizedLink -Link $Source
        if (-not $validatedSingleSourceUrl) {
            throw "Source is not a valid HTTP/HTTPS URL: $Source"
        }

        if (Test-IsPrivateUrl $validatedSingleSourceUrl) {
            throw "SSRF Blocked: Source URL targets a private/internal network ($validatedSingleSourceUrl)."
        }
    }

    # Ensure all parent folders exist before creating/truncating any files.
    # This avoids overwriting the output and only then discovering that the log,
    # failed-URL, or progress folder cannot be created.
    foreach ($pathToPrepare in @($OutputFile, $FailedUrlFile, $LogCsv, $ProgressFile)) {
        if ([string]::IsNullOrWhiteSpace($pathToPrepare)) { continue }
        $folderToPrepare = Split-Path -Parent $pathToPrepare
        if ($folderToPrepare -and -not (Test-Path -LiteralPath $folderToPrepare)) {
            [void](New-Item -ItemType Directory -Path $folderToPrepare -Force)
        }
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

    # Compute patterns and signature before resume filtering and start-phase maintenance
    $effectiveSearchPatterns = @(Get-EffectiveSearchPatterns -MainPattern $SearchPattern -PatternList $SearchPatterns)
    $effectiveExcludePatterns = @(Get-EffectiveExcludePatterns -MainPattern $ExcludePattern -PatternList $ExcludePatterns)

    $runSignature = Get-RunSignature `
        -Source $Source `
        -SourceType $SourceType `
        -OutputFile $OutputFile `
        -SearchPatterns $effectiveSearchPatterns `
        -SearchMode $SearchMode `
        -ExcludePatterns $effectiveExcludePatterns `
        -ExcludeMode $ExcludeMode `
        -BlacklistScope $BlacklistScope `
        -BlacklistPaths $BlacklistFile `
        -SecondFetch $SecondFetch `
        -EnforceRobotsTxt ([bool]$EnforceRobotsTxt) `
        -RobotsUserAgent $RobotsUserAgent `
        -KeepDuplicates $KeepDuplicates `
        -NoDuplicates $NoDuplicates `
        -KeepFragments $KeepFragments `
        -StripRegexBeforeEvaluation ([bool]$StripRegexBeforeEvaluation) `
        -LinkEvaluationStripRegex $LinkEvaluationStripRegex

    # Validate resume signature before start-phase maintenance and source filtering
    $completedSourceSet = $null
    if ($SourceType -eq "File" -and $Resume -and $ProgressFile -and (Test-Path -LiteralPath $ProgressFile)) {
        $completedSourceSet = Initialize-ProgressFile `
            -Path $ProgressFile `
            -Signature $runSignature `
            -Resume:$true

        if ($completedSourceSet -and $completedSourceSet.Count -gt 0 -and (Test-Path -LiteralPath $OutputFile)) {
            $resumeOutputInfo = Get-Item -LiteralPath $OutputFile -ErrorAction Stop
            if ($resumeOutputInfo.Length -eq 0) {
                throw "Resume progress contains $($completedSourceSet.Count) completed source URL(s), but the output file is empty: $OutputFile. Refusing to skip already completed URLs because their previous matches may have been lost. Restore the output file, delete the progress file to restart, or use a different -ProgressFile."
            }
        }
    }

    # Optional start-phase file maintenance before loading source/output/blacklist sets.
    Invoke-ProcessingMaintenancePhase `
        -Phase "Start" `
        -DeduplicateWhenValue $DeduplicateWhen `
        -SortWhenValue $SortWhen `
        -SortDirectionValue $SortDirection `
        -SourceTypeValue $SourceType `
        -SourcePath $Source `
        -OutputPath $OutputFile `
        -BlacklistPaths $BlacklistFile `
        -KeepFragments $KeepFragments

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
                    # Existing output may contain either already-stripped values from a
                    # previous run or original/raw values from an older run. Store both
                    # keys so duplicate checks work without stripping an already-stripped
                    # output line a second time.
                    [void]$writtenSet.TryAdd((Get-LinkKey -Link $line -KeepFragments $KeepFragments), [byte]0)
                    if ($Script:StripRegexBeforeEvaluation) {
                        [void]$writtenSet.TryAdd((Get-LinkKey -Link $line -KeepFragments $KeepFragments -UseEvaluationValue $true), [byte]0)
                    }
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
                        $normalized = ConvertTo-NormalizedLink -Link $blLine
                        if ($normalized) {
                            [void]$blacklistSet.TryAdd((Get-LinkKey -Link $normalized -KeepFragments $KeepFragments), [byte]0)
                            if ($Script:StripRegexBeforeEvaluation) {
                                [void]$blacklistSet.TryAdd((Get-LinkKey -Link $normalized -KeepFragments $KeepFragments -UseEvaluationValue $true), [byte]0)
                            }
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
    if ($Script:StripRegexBeforeEvaluation) {
        Write-Host "Link evaluation regex stripping: enabled. Regex removed before matching/output/dedup: $LinkEvaluationStripRegex"
    }
    if ($Script:CrawlEnabled) {
        $subdomainText = if ($FollowSubdomains) {
            if ($MaxSubdomainDepth -eq 0) { "enabled, unlimited subdomain depth" } else { "enabled, max subdomain depth $MaxSubdomainDepth" }
        }
        else {
            "disabled except seed/apex/www hosts"
        }
        $capText = if ($MaxFollowPages -eq 0) { "no page cap" } else { "max $MaxFollowPages fetched page(s)" }
        $pathScopeText = if ($FollowPathScope -eq "SeedPath") { "seed URL path subtree" } else { "any allowed path" }
        Write-Host "Crawl enabled: FollowDepth=$($Script:FollowDepthDisplay), FollowScope=$FollowScope, FollowPathScope=$FollowPathScope, path=$pathScopeText, subdomains=$subdomainText, $capText."
        Write-Host "Crawl discovery ignores SearchPattern; SearchPattern only controls what is written."
        if ($Script:FollowDepthUnlimited -and $MaxFollowPages -eq 0) {
            Write-Warning "Unbounded crawl requested: unlimited depth and no MaxFollowPages cap. The crawl will stop only when the allowed frontier is exhausted or the run is interrupted."
        }
    }
    if ($EnforceRobotsTxt) {
        Write-Host "robots.txt enforcement enabled. User-agent token: $RobotsUserAgent."
    }


    $totalWritten        = 0
    $totalExtracted      = 0
    $totalMatched        = 0
    $totalExcluded       = 0
    $totalBlacklistSrc   = 0
    $totalBlacklistOut   = 0
    $totalDupes          = 0
    $totalFailed         = 0
    $totalRobotsBlocked  = 0

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
        # Escape fields that might contain commas or quotes.
        # Prefix formula-like values so spreadsheet apps do not treat logs as formulas.
        $cleanUrl   = if ($null -eq $Url) { "" } else { [string]$Url }
        $cleanError = if ($null -eq $ErrorMsg) { "" } else { [string]$ErrorMsg }
        $cleanUrl   = $cleanUrl -replace "[\r\n\t]+", " "
        $cleanError = $cleanError -replace "[\r\n\t]+", " "
        if ($cleanUrl -match '^[=+\-@]')   { $cleanUrl   = "'$cleanUrl" }
        if ($cleanError -match '^[=+\-@]') { $cleanError = "'$cleanError" }
        $safeUrl   = '"' + $cleanUrl.Replace('"', '""') + '"'
        $safeError = '"' + $cleanError.Replace('"', '""') + '"'

        $row = "$ts,$safeUrl,$Status,$Extracted,$Matched,$Excluded,$Blacklisted,$Duplicates,$Written,$safeError"
        $safeLogPath = Get-SafeAbsolutePath $LogCsv

        try {
            Write-FileWithRetry -FilePath $safeLogPath -Content $row
        }
        catch {
            Write-Warning "Could not write CSV log row to $LogCsv. Continuing without treating this URL as failed. $($_.Exception.Message)"
        }
    }

    # Helper: Write failed URLs to error tracking file
    function Write-FailedUrlRow {
        param(
            [string]$Url,
            [string]$ErrorMsg
        )

        if (-not $FailedUrlFile) { return }

        $safeUrl = if ($null -eq $Url) { "" } else { [string]$Url }
        $safeError = if ($null -eq $ErrorMsg) { "Unknown error" } else { [string]$ErrorMsg }
        $safeUrl = $safeUrl -replace "[\r\n\t]+", " "
        $safeError = $safeError -replace "[\r\n\t]+", " "
        if ($safeUrl -match '^[=+\-@]') { $safeUrl = "'$safeUrl" }
        if ($safeError -match '^[=+\-@]') { $safeError = "'$safeError" }
        $failedLine = "$safeUrl`t$safeError"

        try {
            $safeFailedPath = Get-SafeAbsolutePath $FailedUrlFile
            Write-FileWithRetry -FilePath $safeFailedPath -Content $failedLine
        }
        catch {
            Write-Warning "Could not write failed URL row to $FailedUrlFile. Continuing. $($_.Exception.Message)"
        }
    }

    function Test-IsFatalProcessingError {
        param([AllowNull()][object]$ErrorObject)

        if ($null -eq $ErrorObject) { return $false }

        $message = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
            $ErrorObject.Exception.Message
        }
        elseif ($ErrorObject.PSObject.Properties['Exception']) {
            $ErrorObject.Exception.Message
        }
        else {
            [string]$ErrorObject
        }

        return ($message -match '^(Output write failed|Progress write failed)')
    }

    function Invoke-UrlFetchAndMatch {
        param(
            [Parameter(Mandatory = $true)][string]$Url,
            [int]$Depth = 0
        )

        try {
            $links = @(Get-LinksFromWebPage `
                -PageUrl $Url `
                -MaxRetries $RetryCount `
                -WaitSec $WaitSeconds `
                -TimeoutSec $TimeoutSeconds `
                -DoSecondFetch ([bool]$SecondFetch) `
                -SecondWaitSec $SecondFetchWait `
                -UserAgentString $UserAgent `
                -ProxyUrl $Proxy `
                -MaxRedirectsCount $Script:MaxRedirects `
                -MaxRetryAfterSecondsValue $Script:MaxRetryAfterSeconds `
                -EnforceRobotsTxt ([bool]$EnforceRobotsTxt) `
                -RobotsUserAgentValue $RobotsUserAgent `
                -MaxPageContentBytesValue $Script:MaxPageContentBytes `
                -MaxPageContentMBValue $Script:MaxPageContentMB)

            $stats = Write-MatchedLinks -Links $links -RegexList $searchRegexList `
                        -SearchMode $SearchMode `
                        -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                        -OutFile $OutputFile -WrittenSet $writtenSet `
                        -BlacklistSet $blacklistSet `
                        -BlacklistScope $BlacklistScope `
                        -KeepDuplicates ([bool]$KeepDuplicates) -NoDuplicates ([bool]$NoDuplicates) -KeepFragments ([bool]$KeepFragments) -UseEvaluationValue ([bool]$StripRegexBeforeEvaluation)

            return [pscustomobject]@{
                Url            = $Url
                Depth          = $Depth
                Status         = "OK"
                Links          = $links
                ExtractedCount = $links.Count
                Stats          = $stats
                ErrorMsg       = ""
            }
        }
        catch {
            if (Test-IsCancellationException $_) { throw }
            if (Test-IsFatalProcessingError $_) { throw }

            $status = if (Test-IsRobotsTxtBlockedError $_) {
                "ROBOTS_BLOCKED"
            }
            elseif (Test-IsRobotsTxtUnavailableError $_) {
                "ROBOTS_UNAVAILABLE"
            }
            else {
                "FAILED"
            }

            return [pscustomobject]@{
                Url            = $Url
                Depth          = $Depth
                Status         = $status
                Links          = @()
                ExtractedCount = 0
                Stats          = $null
                ErrorMsg       = $_.Exception.Message
            }
        }
    }

    function Invoke-CrawlSequential {
        param(
            [Parameter(Mandatory = $true)][string[]]$SeedUrls,
            [switch]$SingleSeedMode
        )

        $boundary = New-FollowBoundary -SeedUrls $SeedUrls -UseEvaluationValue ([bool]$StripRegexBeforeEvaluation)
        $queue = [System.Collections.Generic.Queue[object]]::new()
        $scheduled = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $initialSkipped = 0

        foreach ($seedUrl in @($SeedUrls)) {
            if ([string]::IsNullOrWhiteSpace($seedUrl)) { continue }

            $normalizedSeed = ConvertTo-NormalizedLink -Link $seedUrl
            if (-not $normalizedSeed) { continue }
            if (Test-IsPrivateUrl $normalizedSeed) { continue }

            if ((Test-BlacklistAppliesToInput -Scope $BlacklistScope) -and (Test-IsBlacklisted -Url $normalizedSeed -BlacklistSet $blacklistSet -KeepFragments $KeepFragments)) {
                $initialSkipped++
                Write-Host "Source URL is blacklisted. Skipping: $normalizedSeed"
                Write-LogCsvRow -Url $normalizedSeed -Status "BLACKLISTED_SOURCE" `
                    -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 1 -Duplicates 0 `
                    -Written 0 -ErrorMsg ""
                continue
            }

            if ($MaxFollowPages -gt 0 -and $scheduled.Count -ge $MaxFollowPages) {
                Write-Host "Crawl page cap reached while scheduling seeds ($MaxFollowPages); remaining seeds will not be queued."
                break
            }

            $seedKey = Get-LinkKey -Link $normalizedSeed -KeepFragments:$false
            if ($scheduled.Add($seedKey)) {
                $queue.Enqueue([pscustomobject]@{ Url = $normalizedSeed; Depth = 0 })
            }
        }

        $script:totalBlacklistSrc += $initialSkipped

        if ($queue.Count -eq 0) {
            if ($initialSkipped -gt 0) {
                Write-Host "No URLs left to fetch after source blacklist filtering."
                return
            }

            throw "No crawl seed URLs available after validation and filtering."
        }

        Write-Host "Crawl seed URL(s): $($queue.Count)"
        if ($FollowPathScope -eq 'SeedPath') {
            Write-Host "Crawl boundary hosts: $($boundary.Hosts.Count); root domain(s): $($boundary.Domains.Count); seed path boundary/boundaries: $($boundary.SeedPathRules.Count)"
        }
        else {
            Write-Host "Crawl boundary hosts: $($boundary.Hosts.Count); root domain(s): $($boundary.Domains.Count)"
        }

        $fetchIndex = 0
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            $fetchIndex++

            Write-Host "[$fetchIndex] Fetching depth $($item.Depth)/$($Script:FollowDepthDisplay): $($item.Url)"
            $result = Invoke-UrlFetchAndMatch -Url $item.Url -Depth ([int]$item.Depth)

            if ($result.Status -eq "OK") {
                $links = @($result.Links)
                $stats = $result.Stats

                $script:totalExtracted += $result.ExtractedCount
                $script:totalMatched += $stats.Matched
                $script:totalExcluded += $stats.Excluded
                $script:totalBlacklistOut += $stats.Blacklisted
                $script:totalDupes += $stats.Duplicates
                $script:totalWritten += $stats.Written

                Write-Host "  Extracted $($result.ExtractedCount) link(s)."
                Write-Host "  Matched: $($stats.Matched) | Excluded: $($stats.Excluded) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written)"

                Write-LogCsvRow -Url $item.Url -Status "OK" `
                    -Extracted $result.ExtractedCount -Matched $stats.Matched `
                    -Excluded $stats.Excluded -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                    -Written $stats.Written -ErrorMsg ""

                if ($Script:FollowDepthUnlimited -or [int]$item.Depth -lt $FollowDepth) {
                    $enqueuedThisPage = 0
                    foreach ($candidate in $links) {
                        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

                        $candidateUrl = ConvertTo-NormalizedLink -Link $candidate
                        if (-not $candidateUrl) { continue }

                        if (-not (Test-UrlAllowedForFollow `
                            -Url $candidateUrl `
                            -Scope $FollowScope `
                            -Boundary $boundary `
                            -PathScope $FollowPathScope `
                            -AllowSubdomains ([bool]$FollowSubdomains) `
                            -MaxSubdomainDepthValue $MaxSubdomainDepth)) {
                            continue
                        }

                        if ((Test-BlacklistAppliesToInput -Scope $BlacklistScope) -and (Test-IsBlacklisted -Url $candidateUrl -BlacklistSet $blacklistSet -KeepFragments $KeepFragments)) {
                            continue
                        }

                        if ($MaxFollowPages -gt 0 -and $scheduled.Count -ge $MaxFollowPages) {
                            continue
                        }

                        $candidateKey = Get-LinkKey -Link $candidateUrl -KeepFragments:$false
                        if ($scheduled.Add($candidateKey)) {
                            $queue.Enqueue([pscustomobject]@{ Url = $candidateUrl; Depth = ([int]$item.Depth + 1) })
                            $enqueuedThisPage++
                        }
                    }

                    if ($enqueuedThisPage -gt 0) {
                        Write-Host "  Enqueued $enqueuedThisPage crawl candidate(s) for next depth. Queue: $($queue.Count). Scheduled total: $($scheduled.Count)."
                    }
                    elseif ($MaxFollowPages -gt 0 -and $scheduled.Count -ge $MaxFollowPages) {
                        Write-Host "  Crawl page cap reached ($MaxFollowPages); no more candidates will be queued."
                    }
                }
            }
            elseif ($result.Status -eq "ROBOTS_BLOCKED") {
                $script:totalRobotsBlocked++
                $robotsMessage = if ([string]::IsNullOrWhiteSpace($result.ErrorMsg)) { "Blocked by robots.txt" } else { $result.ErrorMsg }
                Write-Host "  ROBOTS: $robotsMessage"
                Write-Host "  Skipping this URL and continuing."

                Write-LogCsvRow -Url $item.Url -Status "ROBOTS_BLOCKED" `
                    -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                    -Written 0 -ErrorMsg $robotsMessage
            }
            else {
                $script:totalFailed++
                $errorMessage = if ([string]::IsNullOrWhiteSpace($result.ErrorMsg)) { "Unknown Network Error" } else { $result.ErrorMsg }
                if ($result.Status -eq "ROBOTS_UNAVAILABLE") {
                    Write-Host "  ROBOTS UNAVAILABLE: $errorMessage"
                }
                else {
                    Write-Host "  FAILED: $errorMessage"
                }
                Write-Host "  Skipping this URL and continuing."

                Write-LogCsvRow -Url $item.Url -Status $result.Status `
                    -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                    -Written 0 -ErrorMsg $errorMessage

                Write-FailedUrlRow -Url $item.Url -ErrorMsg $errorMessage
            }

            if ($queue.Count -gt 0 -and $DelaySeconds -gt 0) {
                Write-Host "  Waiting $DelaySeconds second(s) before next URL ..."
                Start-Sleep -Seconds $DelaySeconds
            }

            Write-Host ""
        }
    }

    if ($Script:CrawlEnabled) {
        if ($SourceType -eq "Url") {
            Invoke-CrawlSequential -SeedUrls @($validatedSingleSourceUrl) -SingleSeedMode
        }
        elseif ($SourceType -eq "File") {
            Write-Host "Reading crawl seed URLs from file: $Source"

            if (-not (Test-Path -LiteralPath $Source)) {
                throw "Input file does not exist: $Source"
            }

            $sourceSafePath = Get-SafeAbsolutePath $Source
            $seedUrls = [System.Collections.Generic.List[string]]::new()
            $seenSeedUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $dupeSeedCount = 0
            $invalidSeedCount = 0
            $privateSeedCount = 0
            $isFirstSeedLine = $true

            $fs = $null
            $reader = $null
            try {
                $fs = [System.IO.FileStream]::new($sourceSafePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)

                while ($null -ne ($line = $reader.ReadLine())) {
                    if ($isFirstSeedLine) { $line = Remove-Bom $line; $isFirstSeedLine = $false }
                    if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) { continue }

                    $lineSeedCandidates = @(Get-NormalizedUrlCandidatesFromText -Text $line)
                    if ($lineSeedCandidates.Count -gt 0) {
                        foreach ($normalized in $lineSeedCandidates) {
                            if (Test-IsPrivateUrl $normalized) {
                                Write-Host "  Skipping private/internal seed URL: $normalized"
                                $privateSeedCount++
                                continue
                            }

                            $key = Get-LinkKey -Link $normalized -KeepFragments:$false
                            if ($seenSeedUrls.Add($key)) {
                                [void]$seedUrls.Add($normalized)
                            }
                            else {
                                $dupeSeedCount++
                            }
                        }
                    }
                    else {
                        $invalidSeedCount++
                    }
                }
            }
            catch {
                throw "Failed to read input file: $($_.Exception.Message)"
            }
            finally {
                if ($null -ne $reader) {
                    $reader.Dispose()
                }
                elseif ($null -ne $fs) {
                    $fs.Dispose()
                }
            }

            Write-Host "Valid unique crawl seed URLs: $($seedUrls.Count)"
            if ($dupeSeedCount -gt 0) { Write-Host "Removed $dupeSeedCount duplicate seed URL(s)." }
            if ($invalidSeedCount -gt 0) { Write-Host "Skipped $invalidSeedCount line(s) with no valid web seed URL." }
            if ($privateSeedCount -gt 0) { Write-Host "Skipped $privateSeedCount private/internal seed URL(s)." }

            if ($seedUrls.Count -eq 0) {
                throw "No valid crawl seed URLs found in input file."
            }

            Invoke-CrawlSequential -SeedUrls ([string[]]$seedUrls.ToArray())
        }
        else {
            throw "Unsupported SourceType: $SourceType"
        }
    }
    elseif ($SourceType -eq "Url") {
        # Single URL mode -- fetch, filter, write. Source was already validated
        # before output/log files were created, so reuse that normalized value.
        $sourceUrl = $validatedSingleSourceUrl

        if ((Test-BlacklistAppliesToInput -Scope $BlacklistScope) -and (Test-IsBlacklisted -Url $sourceUrl -BlacklistSet $blacklistSet -KeepFragments $KeepFragments)) {
            Write-Host "Source URL is blacklisted. Skipping: $sourceUrl"
            $totalBlacklistSrc++

            Write-LogCsvRow -Url $sourceUrl -Status "BLACKLISTED_SOURCE" `
                -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 1 -Duplicates 0 `
                -Written 0 -ErrorMsg ""
        }
        else {
            Write-Host "Fetching page: $sourceUrl"
            try {
                $links = @(Get-LinksFromWebPage `
                    -PageUrl $sourceUrl `
                    -MaxRetries $RetryCount `
                    -WaitSec $WaitSeconds `
                    -TimeoutSec $TimeoutSeconds `
                    -DoSecondFetch ([bool]$SecondFetch) `
                    -SecondWaitSec $SecondFetchWait `
                    -UserAgentString $UserAgent `
                    -ProxyUrl $Proxy `
                    -MaxRedirectsCount $Script:MaxRedirects `
                    -MaxRetryAfterSecondsValue $Script:MaxRetryAfterSeconds `
                    -EnforceRobotsTxt ([bool]$EnforceRobotsTxt) `
                    -RobotsUserAgentValue $RobotsUserAgent `
                    -MaxPageContentBytesValue $Script:MaxPageContentBytes `
                    -MaxPageContentMBValue $Script:MaxPageContentMB)
                $totalExtracted = $links.Count
                Write-Host "  Extracted $($links.Count) link(s)."

                $stats = Write-MatchedLinks -Links $links -RegexList $searchRegexList `
                            -SearchMode $SearchMode `
                            -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                            -OutFile $OutputFile -WrittenSet $writtenSet `
                            -BlacklistSet $blacklistSet `
                            -BlacklistScope $BlacklistScope `
                            -KeepDuplicates ([bool]$KeepDuplicates) -NoDuplicates ([bool]$NoDuplicates) -KeepFragments ([bool]$KeepFragments) -UseEvaluationValue ([bool]$StripRegexBeforeEvaluation)
                $totalMatched        += $stats.Matched
                $totalExcluded       += $stats.Excluded
                $totalBlacklistOut   += $stats.Blacklisted
                $totalDupes          += $stats.Duplicates
                $totalWritten        += $stats.Written

                Write-Host "  Matched: $($stats.Matched) | Excluded: $($stats.Excluded) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written)"

                Write-LogCsvRow -Url $sourceUrl -Status "OK" `
                    -Extracted $links.Count -Matched $stats.Matched `
                    -Excluded $stats.Excluded -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                    -Written $stats.Written -ErrorMsg ""
            }
            catch {
                if (Test-IsCancellationException $_) { throw }
                if (Test-IsFatalProcessingError $_) { throw }

                $errorMessage = $_.Exception.Message
                if (Test-IsRobotsTxtBlockedError $_) {
                    $totalRobotsBlocked++
                    Write-Host "  ROBOTS: $errorMessage"
                    Write-LogCsvRow -Url $sourceUrl -Status "ROBOTS_BLOCKED" `
                        -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                        -Written 0 -ErrorMsg $errorMessage
                }
                else {
                    $totalFailed++
                    if (Test-IsRobotsTxtUnavailableError $_) {
                        Write-Host "  ROBOTS UNAVAILABLE: $errorMessage"
                        $logStatus = "ROBOTS_UNAVAILABLE"
                    }
                    else {
                        Write-Host "  FAILED: $errorMessage"
                        $logStatus = "FAILED"
                    }

                    Write-LogCsvRow -Url $sourceUrl -Status $logStatus `
                        -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                        -Written 0 -ErrorMsg $errorMessage

                    Write-FailedUrlRow -Url $sourceUrl -ErrorMsg $errorMessage
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
        $invalidSourceCount = 0
        $privateSourceCount = 0

        Write-Host "Streaming source URLs from file..."
        $isFirstLine = $true

        $fs = $null
        $reader = $null
        try {
            $fs = [System.IO.FileStream]::new($sourceSafePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)

            while ($null -ne ($line = $reader.ReadLine())) {
                # #23: Strip BOM from first line if present
                if ($isFirstLine) { $line = Remove-Bom $line; $isFirstLine = $false }
                if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) { continue }

                $lineSourceCandidates = @(Get-NormalizedUrlCandidatesFromText -Text $line)
                if ($lineSourceCandidates.Count -gt 0) {
                    foreach ($normalized in $lineSourceCandidates) {
                        # #36: Skip private/internal URLs (SSRF protection)
                        if (Test-IsPrivateUrl $normalized) {
                            Write-Host "  Skipping private/internal URL: $normalized"
                            $privateSourceCount++
                            continue
                        }
                        $key = Get-LinkKey -Link $normalized -KeepFragments $KeepFragments
                        if ($seenSourceUrls.Add($key)) {
                            [void]$urls.Add($normalized)
                        }
                        else {
                            $dupeSourceCount++
                        }
                    }
                }
                else {
                    $invalidSourceCount++
                }
            }
        }
        catch {
            throw "Failed to read input file: $($_.Exception.Message)"
        }
        finally {
            if ($null -ne $reader) {
                $reader.Dispose()
            }
            elseif ($null -ne $fs) {
                $fs.Dispose()
            }
        }

        Write-Host "Valid unique source URLs: $($urls.Count)"
        if ($dupeSourceCount -gt 0) {
            Write-Host "Removed $dupeSourceCount duplicate source URL(s)."
        }
        if ($invalidSourceCount -gt 0) {
            Write-Host "Skipped $invalidSourceCount line(s) with no valid web source URL."
        }
        if ($privateSourceCount -gt 0) {
            Write-Host "Skipped $privateSourceCount private/internal source URL(s)."
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
        if ((Test-BlacklistAppliesToInput -Scope $BlacklistScope) -and $blacklistSet.Count -gt 0) {
            $beforeInputBlacklist = $urls.Count

            $blacklistedSourceUrls = @($urls.Where({
                Test-IsBlacklisted -Url $_ -BlacklistSet $blacklistSet -KeepFragments $KeepFragments
            }))

            $urls = @($urls.Where({
                -not (Test-IsBlacklisted -Url $_ -BlacklistSet $blacklistSet -KeepFragments $KeepFragments)
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
                -not $completedSourceSet.ContainsKey((Get-LinkKey -Link $_ -KeepFragments $KeepFragments))
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
            elseif ((Test-BlacklistAppliesToInput -Scope $BlacklistScope) -and $totalBlacklistSrc -gt 0) {
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
                # Load the functions required by worker-side fetch/extract logic.
                # The list is the transitive closure of Get-LinksFromWebPage's call
                # graph, plus Get-LinkKey which serves as the runspace-initialised
                # canary tested below. Keep this list aligned with that closure
                # whenever helpers are added or removed -- a missing entry causes
                # parallel mode to fail with a "command not found" error inside
                # the worker, which is hard to diagnose from the parent.
                $funcNames = @(
                    'Get-LinkKey', 'Get-LinkEvaluationValue', 'Test-IsLikelyRelativeAssetPath', 'Limit-NormalizedLinkLength', 'ConvertTo-NormalizedLink',
                    'ConvertFrom-JsUrl', 'Invoke-WebRequestWithRetry',
                    'Get-RobotsOriginKey', 'Get-RobotsTxtUrlForUrl', 'Get-RobotsPathAndQuery',
                    'New-RobotsPathRule', 'Add-RobotsGroupIfPresent', 'ConvertFrom-RobotsTxt',
                    'Test-RobotsAgentMatches', 'Get-RobotsApplicableRules', 'Test-RobotsPathMatchesPattern',
                    'Test-RobotsPathAllowedByRules', 'New-RobotsPolicyObject', 'Get-RobotsHttpStatusFromErrorMessage',
                    'Get-RobotsPolicyForUrl', 'Test-RobotsTxtAllowed', 'Assert-RobotsTxtAllowsUrl',
                    'Test-IsRobotsTxtBlockedError', 'Test-IsRobotsTxtUnavailableError',
                    'Get-LinksFromWebPage', 'Close-BaseResponseSafe',
                    'Test-IsCancellationException', 'Test-IsInvalidWebRequestStateError',
                    'Test-IsPrivateIPAddress', 'Test-IsPrivateUrl', 'Resolve-SearchEngineLink',
                    'New-FindWebLinksRequestSession', 'Get-RedirectTargetViaRawRequest', 'Get-FindWebLinksProxyParameters',
                    'Get-ResponseStatusCode', 'Get-ResponseHeaderValue',
                    'Get-ResponseMediaType', 'Test-IsSupportedTextMediaType',
                    'Get-ErrorResponse', 'Get-ResponseFinalUrl', 'Get-ResponseContentText', 'Get-ResponseContentLengthSafe',
                    'Get-RegexMatchesSafe', 'Get-RegexFirstMatchSafe', 'Test-IsRegexTimeoutException',
                    'Split-SrcsetValue', 'Add-FoundLinkCandidate'
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
                        KeepFragments   = [bool]$KeepFragments
                        # Recreate MaxUrlLength in worker state because
                        # Limit-NormalizedLinkLength (called transitively via
                        # ConvertTo-NormalizedLink from Get-LinksFromWebPage and
                        # Invoke-WebRequestWithRetry) reads it from Script scope.
                        # Without this propagation a worker would silently use 0.
                        MaxUrlLength    = $Script:MaxUrlLength
                        MaxRedirects    = $Script:MaxRedirects
                        MaxRetryAfterSeconds = $Script:MaxRetryAfterSeconds
                        MaxPageContentMB = $Script:MaxPageContentMB
                        MaxPageContentBytes = $Script:MaxPageContentBytes
                        EnforceRobotsTxt = [bool]$EnforceRobotsTxt
                        RobotsUserAgent = $RobotsUserAgent
                        MaxRobotsTxtBytes = $Script:MaxRobotsTxtBytes
                        RegexTimeoutSeconds = $RegexTimeoutSeconds
                        DnsResolutionTimeoutSeconds = $Script:DnsResolutionTimeoutSeconds
                    }
                } | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                    $url = $_.Url

                    # Recreate operational limits used by worker functions.
                    $Script:MaxUrlLength = $_.MaxUrlLength
                    $Script:MaxRedirects = $_.MaxRedirects
                    $Script:MaxRetryAfterSeconds = $_.MaxRetryAfterSeconds
                    $Script:MaxPageContentBytes = $_.MaxPageContentBytes
                    $Script:MaxPageContentMB = $_.MaxPageContentMB
                    $Script:MaxRobotsTxtBytes = $_.MaxRobotsTxtBytes
                    $Script:RobotsTxtCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    $Script:DnsResolutionTimeoutSeconds = $_.DnsResolutionTimeoutSeconds
                    $Script:RegexTimeout = if ($_.RegexTimeoutSeconds -eq 0) {
                        [System.Text.RegularExpressions.Regex]::InfiniteMatchTimeout
                    }
                    else {
                        [TimeSpan]::FromSeconds($_.RegexTimeoutSeconds)
                    }
                    # Parallel workers only fetch/extract. Link-evaluation stripping is
                    # applied centrally in the parent thread when results are written.
                    $Script:StripRegexBeforeEvaluation = $false
                    $Script:LinkEvaluationStripRegexText = $null
                    $Script:LinkEvaluationStripRegexObject = $null
                    $Script:LinkEvaluationStripRegexWarned = $false

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
                        $global:RegexAttr = [regex]::new('\b(?<attr>href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*["''](?<url>[^"'']+)["'']', $cOpts, $tOut)
                        $global:RegexUnquotedAttr = [regex]::new('\b(?<attr>href|src|action|data-href|data-url|data-src|data-link|data-redirect|formaction|poster|srcset)\s*=\s*(?<url>[^\s"''>]+)', $cOpts, $tOut)
                        $global:RegexRawUrl = [regex]::new('(?x)(?:https?://[^\s<>"''\)\]\}]+|//[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(?::\d+)?(?:[/?#][^\s<>"''\)\]\}]*)?|www\.[^\s<>"''\)\]\}]+|(?<![@/\w.-])[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(?::\d+)?(?:[/?#][^\s<>"''\)\]\}]*)?)', $cOpts, $tOut)
                        $global:RegexScript = [regex]::new('<script[^>]*>(?<body>.*?)</script>', $cOpts -bor [System.Text.RegularExpressions.RegexOptions]::Singleline, $tOut)
                        $global:RegexJsUrl = [regex]::new('(?:"|''|`)(?<url>(?:https?:)?(?:\\?/){2}[^"''`\s]{5,})(?:"|''|`)', $cOpts, $tOut)
                        $global:RegexJsonPath = [regex]::new('"[^"]*"\s*:\s*"(?<url>\\?/[^"]{2,}|https?:\\?/\\?/[^"]+)"', $cOpts, $tOut)
                        $global:RegexNoscript = [regex]::new('<noscript[^>]*>(?<body>.*?)</noscript>', $cOpts -bor [System.Text.RegularExpressions.RegexOptions]::Singleline, $tOut)
                        $global:RegexCssUrl = [regex]::new('url\(\s*["'']?(?<url>[^"''\)\s]+)["'']?\s*\)', $cOpts, $tOut)
                        $global:RegexMetaRefresh = [regex]::new('<meta\b(?=[^>]*http-equiv\s*=\s*["'']?refresh["'']?)(?=[^>]*content\s*=\s*["'']?\s*\d+\s*;\s*url\s*=\s*["'']*(?<url>[^"''\s>]+))[^>]*>', $cOpts -bor [System.Text.RegularExpressions.RegexOptions]::Singleline, $tOut)
                        $global:RegexBaseHref = [regex]::new('<base[^>]+href\s*=\s*(?:["''](?<href>[^"'']+)["'']|(?<href>[^\s"''>]+))', $cOpts, $tOut)
                        $global:RegexMetaContentUrl = [regex]::new('<meta[^>]+content\s*=\s*["''](?<url>https?://[^"'']+)["'']', $cOpts, $tOut)
                        $global:RegexStyleImport = [regex]::new('@import\s+(?:url\()?\s*["'']?(?<url>[^"''\)\s;]+)["'']?\s*\)?', $cOpts, $tOut)
                    }

                    $ProgressPreference = 'SilentlyContinue'
                    $ErrorActionPreference = 'Stop'
                    $WarningPreference = 'SilentlyContinue'
                    $InformationPreference = 'SilentlyContinue'
                    $VerbosePreference = 'SilentlyContinue'

                    # Rate-limit: stagger parallel requests if DelaySeconds is set
                    $delaySeconds = [double]$_.DelaySeconds
                    if ($delaySeconds -gt 0) {
                        $maxDelayMsLong = [int64][Math]::Min(($delaySeconds * 1000.0), [double]([int]::MaxValue - 1))
                        if ($maxDelayMsLong -gt 0) {
                            $maxDelayMs = [int]$maxDelayMsLong
                            Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum $maxDelayMs)
                        }
                    }

                    try {
                        $links = @(Get-LinksFromWebPage `
                            -PageUrl $url `
                            -MaxRetries $_.RetryCount `
                            -WaitSec $_.WaitSeconds `
                            -TimeoutSec $_.TimeoutSeconds `
                            -DoSecondFetch ([bool]$_.SecondFetch) `
                            -SecondWaitSec $_.SecondFetchWait `
                            -UserAgentString $_.UserAgent `
                            -ProxyUrl $_.Proxy `
                            -MaxRedirectsCount $_.MaxRedirects `
                            -MaxRetryAfterSecondsValue $_.MaxRetryAfterSeconds `
                            -EnforceRobotsTxt ([bool]$_.EnforceRobotsTxt) `
                            -RobotsUserAgentValue $_.RobotsUserAgent `
                            -MaxPageContentBytesValue $_.MaxPageContentBytes `
                            -MaxPageContentMBValue $_.MaxPageContentMB)
                        Write-Host "[parallel] OK: $url -- Extracted $($links.Count) link(s)"

                        [pscustomobject]@{
                            Url            = $url
                            Links          = $links
                            ExtractedCount = $links.Count
                            Status         = "OK"
                            ErrorMsg       = ""
                        }
                    }
                    catch {
                        if (Test-IsCancellationException $_) { throw }

                        $status = if (Test-IsRobotsTxtBlockedError $_) {
                            "ROBOTS_BLOCKED"
                        }
                        elseif (Test-IsRobotsTxtUnavailableError $_) {
                            "ROBOTS_UNAVAILABLE"
                        }
                        else {
                            "FAILED"
                        }

                        if ($status -eq "ROBOTS_BLOCKED") {
                            Write-Host "[parallel] ROBOTS: $url -- $($_.Exception.Message)"
                        }
                        elseif ($status -eq "ROBOTS_UNAVAILABLE") {
                            Write-Host "[parallel] ROBOTS UNAVAILABLE: $url -- $($_.Exception.Message)"
                        }
                        else {
                            Write-Host "[parallel] FAILED: $url -- $($_.Exception.Message)"
                        }

                        [pscustomobject]@{
                            Url            = $url
                            Links          = @()
                            ExtractedCount = 0
                            Status         = $status
                            ErrorMsg       = $_.Exception.Message
                        }
                    }
                } | ForEach-Object {
                    # Parent thread: filter, write, log, progress — all central, no races
                    $r = $_

                    try {
                    if ($r.Status -eq "OK") {
                        $resultLinks = @($r.Links)
                        $extractedCount = if ($null -ne $r.PSObject.Properties['ExtractedCount']) { [int]$r.ExtractedCount } else { $resultLinks.Count }
                        $totalExtracted += $extractedCount
                        Write-Host "Fetched: $($r.Url) (Extracted $extractedCount link(s))"

                        $stats = Write-MatchedLinks -Links $resultLinks -RegexList $searchRegexList `
                                    -SearchMode $SearchMode `
                                    -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                                    -OutFile $OutputFile -WrittenSet $writtenSet `
                                    -BlacklistSet $blacklistSet `
                                    -BlacklistScope $BlacklistScope `
                                    -KeepDuplicates ([bool]$KeepDuplicates) -NoDuplicates ([bool]$NoDuplicates) -KeepFragments ([bool]$KeepFragments) -UseEvaluationValue ([bool]$StripRegexBeforeEvaluation)
                        $totalMatched      += $stats.Matched
                        $totalExcluded     += $stats.Excluded
                        $totalBlacklistOut += $stats.Blacklisted
                        $totalDupes        += $stats.Duplicates
                        $totalWritten      += $stats.Written

                        Write-Host "  Matched: $($stats.Matched) | Excluded: $($stats.Excluded) | Blacklisted: $($stats.Blacklisted) | Duplicates: $($stats.Duplicates) | Written: $($stats.Written) -- $($r.Url)"

                        Write-LogCsvRow -Url $r.Url -Status "OK" `
                            -Extracted $extractedCount -Matched $stats.Matched `
                            -Excluded $stats.Excluded -Blacklisted $stats.Blacklisted -Duplicates $stats.Duplicates `
                            -Written $stats.Written -ErrorMsg ""
                    }
                    else {
                        $totalFailed++
                        $safeErrorMsg = if ([string]::IsNullOrWhiteSpace($r.ErrorMsg)) { "Unknown Network Error" } else { $r.ErrorMsg }
                        Write-Host "FAILED: $($r.Url) -- $safeErrorMsg"

                        Write-LogCsvRow -Url $r.Url -Status "FAILED" `
                            -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                            -Written 0 -ErrorMsg $safeErrorMsg

                        Write-FailedUrlRow -Url $r.Url -ErrorMsg $safeErrorMsg
                    }

                    if ($r.Status -eq "OK" -and $ProgressFile -and $completedSourceSet) {
                        Add-CompletedProgress `
                            -Path $ProgressFile `
                            -Url $r.Url `
                            -CompletedSet $completedSourceSet `
                            -KeepFragments ([bool]$KeepFragments)
                    }
                    }
                    catch {
                        if (Test-IsCancellationException $_) { throw }
                        if (Test-IsFatalProcessingError $_) { throw }

                        $totalFailed++
                        $safeErrMsg = $_.Exception.Message
                        Write-Host "  ERROR processing result for $($r.Url): $safeErrMsg"

                        Write-LogCsvRow -Url $r.Url -Status "FAILED" `
                            -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                            -Written 0 -ErrorMsg $safeErrMsg

                        Write-FailedUrlRow -Url $r.Url -ErrorMsg $safeErrMsg
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
                    $markProgressForUrl = $false
                    Write-Host "[$index / $($urls.Count)] Fetching: $url"

                    try {
                        $links = @(Get-LinksFromWebPage `
                            -PageUrl $url `
                            -MaxRetries $RetryCount `
                            -WaitSec $WaitSeconds `
                            -TimeoutSec $TimeoutSeconds `
                            -DoSecondFetch ([bool]$SecondFetch) `
                            -SecondWaitSec $SecondFetchWait `
                            -UserAgentString $UserAgent `
                            -ProxyUrl $Proxy `
                            -MaxRedirectsCount $Script:MaxRedirects `
                            -MaxRetryAfterSecondsValue $Script:MaxRetryAfterSeconds `
                            -EnforceRobotsTxt ([bool]$EnforceRobotsTxt) `
                            -RobotsUserAgentValue $RobotsUserAgent `
                            -MaxPageContentBytesValue $Script:MaxPageContentBytes `
                            -MaxPageContentMBValue $Script:MaxPageContentMB)
                        $totalExtracted += $links.Count
                        Write-Host "  Extracted $($links.Count) link(s)."

                        $stats = Write-MatchedLinks -Links $links -RegexList $searchRegexList `
                                    -SearchMode $SearchMode `
                                    -ExcludeRegexList $excludeRegexList -ExcludeMode $ExcludeMode `
                                    -OutFile $OutputFile -WrittenSet $writtenSet `
                                    -BlacklistSet $blacklistSet `
                                    -BlacklistScope $BlacklistScope `
                                    -KeepDuplicates ([bool]$KeepDuplicates) -NoDuplicates ([bool]$NoDuplicates) -KeepFragments ([bool]$KeepFragments) -UseEvaluationValue ([bool]$StripRegexBeforeEvaluation)
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

                        $markProgressForUrl = $true
                    }
                    catch {
                        if (Test-IsCancellationException $_) { throw }
                        if (Test-IsFatalProcessingError $_) { throw }

                        $errorMessage = $_.Exception.Message

                        if (Test-IsRobotsTxtBlockedError $_) {
                            $totalRobotsBlocked++
                            Write-Host "  ROBOTS: $errorMessage"
                            Write-Host "  Skipping this URL and continuing."

                            Write-LogCsvRow -Url $url -Status "ROBOTS_BLOCKED" `
                                -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                                -Written 0 -ErrorMsg $errorMessage
                        }
                        else {
                            $totalFailed++
                            if (Test-IsRobotsTxtUnavailableError $_) {
                                Write-Host "  ROBOTS UNAVAILABLE: $errorMessage"
                                $logStatus = "ROBOTS_UNAVAILABLE"
                            }
                            else {
                                Write-Host "  FAILED: $errorMessage"
                                $logStatus = "FAILED"
                            }
                            Write-Host "  Skipping this URL and continuing."

                            Write-LogCsvRow -Url $url -Status $logStatus `
                                -Extracted 0 -Matched 0 -Excluded 0 -Blacklisted 0 -Duplicates 0 `
                                -Written 0 -ErrorMsg $errorMessage

                            Write-FailedUrlRow -Url $url -ErrorMsg $errorMessage
                        }
                    }

                    if ($markProgressForUrl -and $ProgressFile -and $completedSourceSet) {
                        Add-CompletedProgress `
                            -Path $ProgressFile `
                            -Url $url `
                            -CompletedSet $completedSourceSet `
                            -KeepFragments ([bool]$KeepFragments)
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

    # Clean up progress file only after a fully successful completed run.
    # If any URL failed, keep the progress file so -Resume can retry only the unfinished/failed URLs.
    if ($SourceType -eq "File" -and (-not $Script:CrawlEnabled) -and $ProgressFile -and (Test-Path -LiteralPath $ProgressFile)) {
        if ($totalFailed -eq 0) {
            Remove-ProgressFileIfSafe `
                -Path $ProgressFile `
                -Reason "Run completed normally."
        }
        else {
            Write-Host "Progress file kept because $totalFailed URL(s) failed. Re-run with -Resume to retry unfinished URLs."
        }
    }

    # Optional end-phase file maintenance after processing has finished.
    Invoke-ProcessingMaintenancePhase `
        -Phase "End" `
        -DeduplicateWhenValue $DeduplicateWhen `
        -SortWhenValue $SortWhen `
        -SortDirectionValue $SortDirection `
        -SourceTypeValue $SourceType `
        -SourcePath $Source `
        -OutputPath $OutputFile `
        -BlacklistPaths $BlacklistFile `
        -KeepFragments $KeepFragments

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
    Write-Host "Total robots.txt blocked:    $totalRobotsBlocked"
    Write-Host "Total duplicates:            $totalDupes"
    Write-Host "Total written to file:       $totalWritten"
    Write-Host "Total failed URLs:           $totalFailed"
    Write-Host "robots.txt enforced:         $EnforceRobotsTxt"
    Write-Host "Evaluation regex stripping:  $($Script:StripRegexBeforeEvaluation)"
    if ($Script:CrawlEnabled) {
        Write-Host "Crawl follow depth:          $($Script:FollowDepthDisplay)"
        Write-Host "Crawl scope:                 $FollowScope"
        Write-Host "Crawl path scope:            $FollowPathScope"
    }

    # #46: Warn if failure rate is suspiciously high
    if ($HighFailureRatePercent -gt 0 -and (-not $Script:CrawlEnabled) -and $SourceType -eq "File" -and $totalFailed -gt 0 -and $urls.Count -gt 0) {
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
    if (Test-IsCancellationException $_) {
        Write-Host "Interrupted by user. Progress file was kept if this was a File-mode run; re-run the same command with -Resume to continue."
        exit 130
    }

    Write-Error "Failed: $($_.Exception.Message)"
    exit 1
}
