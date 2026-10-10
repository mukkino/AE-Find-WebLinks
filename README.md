# AE-Find-WebLinks

**Current release:** [1.8.0](https://github.com/mukkino/AE-Find-WebLinks/releases/tag/v1.8.0)  
**Release date:** 15 September 2026  
**Author:** Fabio Lichinchi (mukka) · [alterego.cc](https://alterego.cc/)  
**Licence:** [The Unlicense](https://github.com/mukkino/AE-Find-WebLinks/blob/main/LICENSE)

[Download the 1.8.0 script](https://github.com/mukkino/AE-Find-WebLinks/releases/download/v1.8.0/AE-Find-WebLinks.ps1) · [All releases](https://github.com/mukkino/AE-Find-WebLinks/releases) · [Source code](https://github.com/mukkino/AE-Find-WebLinks/blob/main/AE-Find-WebLinks/AE-Find-WebLinks.ps1) · [Project page](https://alterego.cc/wp/ae-find-weblinks/)

AE-Find-WebLinks is a PowerShell command-line tool for extracting, filtering, saving, and optionally crawling web links from either a single web page or a text file containing many source URLs.

It is built for link discovery, archive preparation, download-list building, deduplication, filtering, blacklist handling, long-running URL jobs, resumable crawling, stuck-URL watchdogs, failed-URL tracking, automatic retries, CSV logging, optional parallel processing, and maintenance of large text URL lists.

The script does **not** require a browser, Selenium, Playwright, ChromeDriver, or external PowerShell modules. It downloads the raw HTTP response and extracts links from common places such as HTML attributes, raw text, script blocks, JSON-like content, CSS `url(...)` references, `noscript` blocks, and embedded URL patterns.

It is a raw-response extraction and crawling tool, not a browser. It does **not** execute JavaScript or render web pages, and it does not download the files referenced by the extracted links.

---

## Contents

- [Requirements](#requirements)
- [Main capabilities](#main-capabilities)
- [Getting started](#getting-started)
- [Matching and excluding links](#matching-and-excluding-links)
- [Output, duplicates and fragments](#output-duplicates-and-fragments)
- [Blacklist files](#blacklist-files)
- [Crawling and link following](#crawling-and-link-following)
- [Crawl depth](#crawl-depth), [page cap](#crawl-page-cap) and [scope](#crawl-scope)
- [Subdomains](#subdomain-handling) and [path boundaries](#path-limited-crawling)
- [Regex stripping](#regex-stripping-before-link-evaluation)
- [robots.txt](#robotstxt-support)
- [Parallel processing](#parallel-processing-and-request-spacing)
- [Progress and resume](#progress-interruption-and-resume)
- [Timeouts, retries and watchdog](#timeouts-retries-and-the-stuck-url-watchdog)
- [HTTP requests](#http-requests-and-response-handling)
- [Logging and failed URLs](#logging-and-failed-urls)
- [Maintenance](#deduplication-sorting-and-standalone-maintenance)
- [Operational limits](#operational-limits)
- [Practical examples](#practical-examples)
- [Exit codes](#exit-codes-and-completion-checks)
- [Version 1.8.0](#whats-included-in-180)
- [Complete parameter reference: all 74 options](#complete-parameter-reference)
- [Parameter compatibility and precedence](#parameter-compatibility-and-precedence)
- [Limitations](#important-limitations)
- [Licence and feedback](#licence-and-feedback)

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+.
- `-ThrottleLimit 1` runs sequentially and is the default. Values greater than `1` require PowerShell 7+; Windows PowerShell 5.1 rejects them.
- No external PowerShell modules required.
- No browser or system installation required. Run from a writable folder, subject to your device's execution policies.

**Parallel processing is available for both URL-file processing and crawling on PowerShell 7+.** Crawling is disabled by default (`-FollowDepth 0`); enable it with a positive depth or `-FollowUntilExhausted`. Crawl mode is no longer limited to sequential processing.

---

## Main capabilities

AE-Find-WebLinks can:

- Scan one URL or many URLs from a text file.
- Extract links from raw HTTP responses, including embedded URLs that do not appear as ordinary clickable links.
- Extract source URL tokens from copied text, logs, CSV-style lines, and HTML-like content.
- Match links using one or multiple wildcard patterns, with `Any` or `All` include logic.
- Exclude links using one or multiple wildcard patterns, with `Any` or `All` exclusion logic.
- Strip regex-matched text from URLs before evaluation, deduplication, or output.
- Crawl to a chosen depth or until the allowed frontier is exhausted, with host/domain, path, subdomain, and page-count limits.
- Process URL lists and crawl frontiers concurrently on PowerShell 7+, with configurable request spacing and optional delay jitter.
- Apply blacklist files to input URLs, extracted output, or both.
- Write matching links to a plain text file in `Append` or `New` mode, with controls for deduplication, repeated occurrences, and URL fragments.
- Save progress and resume interrupted URL-file jobs or crawls using `-Resume`.
- Retry failed requests, restart stuck URLs through a configurable watchdog, and optionally run one additional failed-URL retry pass with `-RetryFailedOnFinish`.
- Stop a run with `-MaxRunMinutes`, retaining progress where enabled for later resume.
- Write per-source CSV statistics and separate failed-URL/error records.
- Use custom request headers, a custom user agent, an explicit proxy, and a selectable default scheme for bare hostnames.
- Deduplicate and sort URL files, either around a normal run or through standalone maintenance commands without fetching pages.
- Build commands interactively, with options to save or run the generated command, and provide built-in help, version reporting, and reduced console output through `-Quiet`.

---

## Getting started

Download `AE-Find-WebLinks.ps1` from the release link above and save it in a writable folder. Open PowerShell in that folder. If you download the repository instead, the script is inside its `AE-Find-WebLinks` subfolder.

```powershell
.\AE-Find-WebLinks.ps1 -Version
.\AE-Find-WebLinks.ps1 -Help
.\AE-Find-WebLinks.ps1 -InteractiveHelp
```

`-Version` reports the script version and PowerShell host. `-Help` (alias `-h`) displays the built-in reference. `-InteractiveHelp` (alias `-Interactive`) opens a guided command builder that can generate, save or run a command. Starting without parameters offers help, the guided builder or exit.

### Scan a single page

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*iana.org*' -OutputFile '.\links.txt' -Mode New
```

`-Mode New` creates or overwrites the output file. `Append` is the default and retains existing output. Links are saved one per line; the linked files themselves are not downloaded.

### Scan a list of source pages

Create `source-urls.txt` with one source URL per line:

```text
https://example.com/archive/
https://example.org/downloads/
```

Then run:

```powershell
.\AE-Find-WebLinks.ps1 -Source '.\source-urls.txt' -SourceType File -SearchPattern '*download*' -OutputFile '.\matched-links.txt' -Mode Append
```

File mode can also extract URL tokens from copied text, logs, CSV-like lines and HTML-like content. A clean list remains easiest to inspect and maintain. The source file supplies URLs to fetch; it is not treated as a locally rendered website.

### Positional syntax

The first five positional arguments are `Source`, `SearchPattern`, `OutputFile`, `Mode` and `SourceType`:

```powershell
.\AE-Find-WebLinks.ps1 '.\source-urls.txt' '*download*' '.\matched-links.txt' Append File
```

Use named parameters for longer commands. Normal extraction requires a source, an output path and a search pattern (or multiple search patterns). Incomplete extraction commands return code `2` before fetching pages or modifying operational output.

### PowerShell switches and Boolean options

Switches such as `-Resume`, `-KeepFragments` and `-FollowUntilExhausted` can stand alone. Boolean parameters need an explicit value:

```powershell
-FollowSubdomains:$true
-SecondFetch:$false
-NoDuplicates:$false
-SortOutput:$true
```

In particular, use **`-FollowSubdomains:$true`**, not a bare `-FollowSubdomains`.

## Matching and excluding links

Search patterns use case-insensitive wildcard matching. Use `*` to match any sequence of characters and `?` to match one character. Patterns match the whole URL, so surround a substring with `*`, such as `'*download*'`. Use `'*'` to save all eligible extracted links.

| Parameter | Purpose | Default |
| --- | --- | --- |
| `-SearchPattern` | One include pattern. | Required unless multiple patterns are supplied. |
| `-SearchPatterns` | An array of include patterns. | None. |
| `-SearchMode Any` | Accept a link matching at least one include pattern. | `Any`. |
| `-SearchMode All` | Require every include pattern to match. | Opt-in. |
| `-ExcludePattern` | One rejection pattern. | None. |
| `-ExcludePatterns` | An array of rejection patterns. | None. |
| `-ExcludeMode Any` | Reject a link matching any exclusion. | `Any`. |
| `-ExcludeMode All` | Reject only when every exclusion matches. | Opt-in. |

Save ZIP or LHA links while excluding preview and thumbnail URLs:

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/downloads/' -SearchPatterns '*.zip*','*.lha*' -SearchMode Any -ExcludePatterns '*preview*','*thumbnail*' -ExcludeMode Any -OutputFile '.\archives.txt' -Mode New
```

Require both `/news/` and `story` in a link:

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPatterns '*/news/*','*story*' -SearchMode All -OutputFile '.\stories.txt' -Mode New
```

Include and exclusion patterns control **saved output**, not crawl discovery. Excluding a URL pattern from output does not prevent the crawler from visiting matching pages. Use crawl boundaries or an input blacklist to restrict fetching.

## Output, duplicates and fragments

By default, output is appended, duplicate output links are suppressed, and fragments such as `#section` are removed from written links and ignored for uniqueness.

| Option | Behaviour |
| --- | --- |
| `-Mode Append` | Preserve existing output and add new matches; default. |
| `-Mode New` | Create or overwrite the output file. |
| `-NoDuplicates:$true` | Suppress links already in the output or written during the run; default. |
| `-NoDuplicates:$false` | Allow repeated output across sources. |
| `-KeepDuplicates` | Retain genuine repeated occurrences on the same page. |
| `-KeepFragments` | Preserve fragments in output and uniqueness comparisons. |

To preserve repeated occurrences both within pages and across sources, combine `-KeepDuplicates -NoDuplicates:$false`.

The code's URL keys are case-insensitive, ignore a trailing slash, and treat HTTP and HTTPS versions as equivalent. This is a practical deduplication policy, not a claim that those URLs always return identical content. Case-sensitive paths can therefore collapse to one key. `-KeepFragments` changes fragment handling, not the other key rules.

Version 1.8.0 reconciles overlapping extraction methods by source position: finding the same occurrence through an HTML attribute and a raw-text scan does not create an artificial duplicate. Newly written output, log, progress and failed-URL files use UTF-8 without a byte-order mark.

## Blacklist files

Supply one or more text files containing exact URLs, one per line:

```powershell
-BlacklistFile '.\already-downloaded.txt','.\blocked-urls.txt' -BlacklistScope Both
```

| Scope | Effect |
| --- | --- |
| `Input` | Skip blacklisted source URLs and blacklist-filtered crawl candidates. |
| `Output` | Suppress blacklisted extracted links from saved results. |
| `Both` | Apply both behaviours; default. |

**Blacklists are URL lists, not domain-blocking or wildcard lists.** An entry for `https://example.com/` does not block `https://example.com/article/`. Comparisons use the normalised URL keys described above, including fragment handling. Missing blacklist files produce a warning and are skipped.

For output filtering across a whole host, use an exclusion pattern such as `'*://example.com/*'`; remember that output exclusions do not restrict crawl discovery.

## Crawling and link following

AE-Find-WebLinks can optionally follow links discovered on source pages.

The crawler has two separate behaviours:

- **Discovery:** which links are allowed to be followed.
- **Saving:** which links are written to the output file.

Crawl discovery intentionally ignores `SearchPattern`. This is important because intermediate index, category, navigation, or pagination pages may not match your search pattern, but they may lead to links that do.

`SearchPattern` and the exclusion patterns control only what is written to the output file.

For example, if you search for:

```text
*news*story*
```

The crawler may still follow pages that do not contain `news` or `story` in the URL, as long as those pages are allowed by the crawl scope. Only links matching `*news*story*` are saved.

---

## Crawl depth

Use `-FollowDepth` to decide how far links should be followed.

|     **Option**    |                                          **Behaviour**                                         |
| :---------------: | :--------------------------------------------------------------------------------------------: |
|  `-FollowDepth 0` |        Default behaviour. No crawling. Only the supplied source URL or URLs are scanned.       |
|  `-FollowDepth 1` |                   Scan the source page, then fetch links found on that page.                   |
|  `-FollowDepth 2` | Scan the source page, fetch links found on that page, then fetch links found one level deeper. |
| `-FollowDepth -1` |                       Crawl until there are no more allowed unseen links.                      |

The clearer equivalent to `-FollowDepth -1` is:

```powershell
-FollowUntilExhausted
```

Aliases are also available:

```powershell
-FollowToEnd
-UnlimitedFollowDepth
```

---

## Crawl page cap

Use `-MaxFollowPages` to limit how many pages the crawler is allowed to schedule and fetch.

Default:

```powershell
-MaxFollowPages 1000
```

The cap includes scheduled source pages and discovered pages. It limits crawl pages, not the number of saved links or individual HTTP requests: redirects, retries, robots checks and second fetches can add requests.

To remove the cap:

```powershell
-MaxFollowPages 0
```

Use `-MaxFollowPages 0` carefully, especially with `-FollowUntilExhausted`, because the crawl will stop only when no more allowed unseen links remain.

---

## Crawl scope

Use `-FollowScope` to control which hosts or domains may be crawled.

Available values:

```powershell
-FollowScope SameDomain
-FollowScope SameHost
-FollowScope Any
```

Default:

```powershell
-FollowScope SameDomain
```

### SameDomain

`SameDomain` uses a built-in approximation of the registrable domain, with default handling for seed, apex and `www` hosts. It is not a full Public Suffix List implementation and cannot reliably model every public or private suffix. Use `SameHost` when you need an exact hostname boundary.

Example seed:

```text
https://example.com/1
```

Allowed:

```text
https://example.com/1
https://example.com/1/2
https://www.example.com/1
```

Rejected by default:

```text
https://blog.example.com/1
https://other-site.com/1
```

### SameHost

`SameHost` is stricter. It allows only the exact same hostname as the seed URL.

Example seed:

```text
https://example.com/1
```

Allowed:

```text
https://example.com/1
https://example.com/1/2
```

Rejected:

```text
https://www.example.com/1
https://blog.example.com/1
https://other-site.com/1
```

Use `SameHost` when you want the crawl locked to the exact host from the input URL.

### Any

`Any` allows external domains, subject to private/internal URL protection, blacklist checks, file-type skipping, depth limits, page caps, and optional robots.txt enforcement.

Use it carefully.

---

## Subdomain handling

By default, subdomain crawling is disabled except for the seed host, apex host, and `www` host handling used by `SameDomain`.

Enable wider subdomain crawling with:

```powershell
-FollowSubdomains:$true
```

Limit how many subdomain levels may be followed with:

```powershell
-MaxSubdomainDepth 1
```

`1` means direct subdomains only.

Examples:

```text
blog.example.com
downloads.example.com
```

`0` means unlimited subdomain depth.

Example:

```text
a.b.c.example.com
```

Defaults:

```powershell
-FollowSubdomains:$false
-MaxSubdomainDepth 1
```

The recommended default is to keep subdomain crawling disabled unless you know the site structure needs it.

---

## Path-limited crawling

Use `-FollowPathScope SeedPath` to keep crawling only inside the starting URL path or subtree.

This is useful when a source URL points to a specific archive section and you do not want the crawler to wander sideways into other parts of the same site.

Example seed:

```text
https://example.com/1
```

With:

```powershell
-FollowPathScope SeedPath
```

Allowed:

```text
https://example.com/1
https://example.com/1/2
https://example.com/1/2/3
```

Rejected:

```text
https://example.com/2
https://example.com/10
https://example.com/1-other
```

The path check is segment-aware, so `/1` does not accidentally match `/10`.

Default:

```powershell
-FollowPathScope Any
```

---

## Regex stripping before link evaluation

Use `-StripRegexBeforeEvaluation` with `-LinkEvaluationStripRegex` when links contain a trailing part that should be ignored for matching and saving.

This is not the same as `-ExcludePattern`. `-ExcludePattern` rejects a link. Regex stripping keeps the link, removes the regex-matched part from the evaluated form, and then uses that evaluated form for:

- search pattern matching;
- exclude pattern checks;
- output blacklist checks;
- duplicate checks against the output file;
- the value written to the output file.

Example links:

```text
https://blog.example.org/article/june/1
https://blog.example.org/article/june/2
https://blog.example.org/article/june/10
https://blog.example.org/article/june/111
```

Command option:

```powershell
-StripRegexBeforeEvaluation -LinkEvaluationStripRegex '/\d+$'
```

Evaluated and written as:

```text
https://blog.example.org/article/june
```

Use an anchored regex when you only want to remove the final part. For example, `/\d+$` removes only a final slash followed by digits. A broader regex will remove whatever it matches.

When crawl mode uses `-FollowPathScope SeedPath`, the seed path boundary is also built from the evaluated seed URL. That means a seed such as `https://blog.example.org/article/june/1` uses `/article/june` as the path boundary when the regex above is enabled.

---

## robots.txt support

AE-Find-WebLinks can enforce `robots.txt`, but this is disabled by default.

Enable it with:

```powershell
-EnforceRobotsTxt
```

Set the user-agent token used for robots matching with:

```powershell
-RobotsUserAgent "AE-Find-WebLinks"
```

When enabled, the script checks `robots.txt` before fetching:

- initial source URLs;
- crawled pages;
- redirect targets.

The script caches `robots.txt` rules per origin to avoid repeatedly downloading the same file.

Missing or 4xx `robots.txt` responses are treated as allowed. Network errors or 5xx responses fail closed for that origin while enforcement is enabled.

Supported robots rules include:

- `User-agent`
- `Allow`
- `Disallow`
- `*` wildcards
- `$` end anchors
- longest-match rule selection
- `Allow` winning ties

Unsupported extensions such as `Crawl-delay`, `Sitemap`, and `Request-rate` are ignored.

Use `-DelaySeconds` for throttling.

---

## Parallel processing and request spacing

**PowerShell 7+ supports parallel URL-file processing and parallel crawling.** The default is sequential operation with `-ThrottleLimit 1`. Windows PowerShell 5.1 rejects values greater than `1`.

```powershell
.\AE-Find-WebLinks.ps1 -Source '.\source-urls.txt' -SourceType File -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -ThrottleLimit 4 -DelaySeconds 5 -DelayJitterSeconds 2
```

`-ThrottleLimit 4` permits up to four active URL workers. Its aliases are `-Parallel` and `-Workers`. It has no benefit for one source URL without crawling.

Workers download and extract links. Matching, deduplication, output writing, logging, progress updates and crawl scheduling stay on the main thread. Parallel completion order can vary; do not expect source-list ordering. With crawl caps or deadlines, which pages complete or enter the frontier can also depend on scheduling.

`-DelaySeconds` defaults to `5`. In parallel mode it spaces request starts across the worker pool. `-DelayJitterSeconds` adds a random extra delay from zero to the specified number of seconds and defaults to `0`. These controls are separate from retry waits and second-fetch waits.

## Progress, interruption and resume

Both URL-file jobs and crawls support saved progress.

| Job type | Default progress path | Recorded state |
| --- | --- | --- |
| File mode without crawling | `<OutputFile>.progress` | Completed source URLs and run signature. |
| Crawl mode, from a URL or file | `<OutputFile>.crawl.progress` | Scheduled (`ENQUEUED`) and completed (`DONE`) URLs, plus run signature. |

Use `-ProgressFile` to choose a different path. A normal single-page extraction without crawling does not provide the same resumable queue workflow.

Start a resumable crawl:

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/archive/' -SearchPattern '*.zip*' -OutputFile '.\archive-links.txt' -Mode Append -FollowDepth 2 -FollowScope SameHost -FollowPathScope SeedPath -MaxFollowPages 1000 -LogCsv '.\archive-log.csv' -FailedUrlFile '.\archive-failed.txt'
```

If interrupted, rerun that same command with `-Resume` added. Preserve the output and progress files, keep the same inputs and signed settings, and use `Append` for output, CSV and failure files. Changing filters or crawl boundaries can invalidate the saved signature. Do not assume older or manually edited progress files are compatible.

If an existing progress file is found during a fresh File/crawl run, the script refuses to overwrite it silently. Resume the job, choose another progress file, or deliberately remove the old progress file when starting over.

**Ctrl+C does not guarantee exit code `130`.** The script returns `130` when its cancellation handler runs, but direct `powershell.exe -File` or `pwsh -File` execution can stop with exit `0` while work remains. After interruption, reconcile the intended sources with the CSV and output. A missing progress file alone is not proof of completion. The release notes report recovery at specific interruption points, not every possible write boundary.

### Limit a run's duration

```powershell
-MaxRunMinutes 60
```

This stops scheduling new URLs after the configured interval and retains progress where enabled for later resume. The default, `0`, means no runtime limit. It is a scheduling limit, not a guarantee that all active requests stop at that exact instant. A deadline stop normally uses exit code `3`.

### Retry failed or unfinished URLs once more

```powershell
-RetryFailedOnFinish
```

When failures leave resumable progress, this requests **one additional resume pass**. It requires an available script path and progress file, forces output/log/failure modes to `Append`, and removes the recursive retry switch. It does not loop indefinitely and does not start the extra pass after a runtime deadline stop.

Aliases: `-AutoRetryFailed`, `-RetryFailedAtEnd`.

## Timeouts, retries and the stuck-URL watchdog

These controls address different parts of processing:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `-TimeoutSeconds` | `120` | Request-attempt deadline covering response headers and body reading. |
| `-RetryCount` | `3` | Maximum attempts per request retry loop, including the first; also bounds watchdog runs. |
| `-WaitSeconds` | `30` | Configured wait between retry attempts. |
| `-StuckUrlTimeoutSeconds` | `300` | Restart processing of a URL when its watchdog expires. |
| `-MaxRetryAfterSeconds` | `300` | Cap for honoured server `Retry-After` waits. |
| `-MaxRedirects` | `10` | Limit for redirect handling, including HTTP and meta-refresh handling. |

The watchdog covers the wider URL-processing workflow, including supported waits and extraction checkpoints. It is separate from the timeout on an individual HTTP attempt. Watchdog restarts are bounded by the retry configuration; these are recovery mechanisms, not a guarantee that an unavailable URL will succeed.

Change or disable the watchdog:

```powershell
-StuckUrlTimeoutSeconds 600
-StuckUrlTimeoutSeconds Disabled
```

`0`, `Off` and `None` also disable it. Aliases are `-SameLinkTimeoutSeconds`, `-UrlWatchdogSeconds` and `-StuckLinkTimeoutSeconds`.

Version 1.8.0 fixes handling of custom and disabled watchdog values, ensures slow-trickle response bodies remain subject to the attempt deadline, and avoids unnecessary request retries for unchanged requests returning HTTP `400` or `405`.

## HTTP requests and response handling

### Second fetch

By default, `-SecondFetch:$true` requests a second fetch, waits `5` seconds (`-SecondFetchWait 5`), and keeps the larger response. This can help when the initial response is smaller or incomplete, but increases traffic and does not execute JavaScript or guarantee access through anti-bot systems.

Disable it when one fetch is sufficient:

```powershell
-SecondFetch:$false
```

### User agent, headers and proxy

```powershell
-UserAgent 'AE-Find-WebLinks/1.8.0' -Header 'Accept-Language: en-GB,en;q=0.9' -Proxy 'http://proxy.example.com:8080'
```

`-Header` accepts an array of `Name: value` strings; `-Headers` is an alias. Use `-UserAgent` for the User-Agent value. Headers such as `Referer` and `Cookie` are supported, but supplying a cookie is not an automated login flow. The default HTTP User-Agent is a browser-style string; `-RobotsUserAgent` is a separate robots-matching token.

### Bare hostnames

`-DefaultScheme https` is the default for bare hosts such as `example.com/archive/`. Use `-DefaultScheme http` when working with sources that genuinely require HTTP. It controls the scheme assumed during normalisation, not a forced downgrade of explicitly HTTPS URLs.

### TLS validation

Certificate validation is enabled by default. `-SkipCertificateCheck` (aliases `-Insecure`, `-IgnoreCertificateErrors`) explicitly disables validation for the request. Keep normal validation enabled unless this exception is intentional.

The code uses request-local .NET transports: `HttpWebRequest` on Windows PowerShell 5.1 and `HttpClient` on PowerShell 7+. `-ConnectionLimit` applies to the 5.1 transport; PowerShell 7 manages its own connections and TLS negotiation.

## Logging and failed URLs

```powershell
-LogCsv '.\run-log.csv' -LogMode Append -FailedUrlFile '.\failed-urls.txt' -FailedUrlMode Append
```

Output, CSV and failed-URL files have independent `Append`/`New` modes. All default to `Append`. `New` overwrites the corresponding file, so retain `Append` when continuing a job.

The source CSV contains:

```text
Timestamp,SourceUrl,Status,Extracted,Matched,Excluded,Blacklisted,Duplicates,Written,Error
```

These fields distinguish links extracted from a response, links matched by filters, links excluded or blacklisted, duplicates suppressed and links actually written. The failed-URL file contains tab-separated source URLs and error details. Logs remain useful after an automatic retry: appended failure records are historical records, not necessarily a list of URLs that still fail.

`-Quiet` (alias `-q`) suppresses detailed processing messages while retaining per-URL summaries, failures, warnings and totals. `-HighFailureRatePercent` defaults to `50`; the high-failure warning applies to non-crawl File runs, and `0` disables it.

## Deduplication, sorting and standalone maintenance

Maintenance can run independently without fetching pages:

```powershell
.\AE-Find-WebLinks.ps1 -Command Deduplicate -Files '.\links.txt'
.\AE-Find-WebLinks.ps1 -Command Sort -Files '.\links.txt' -SortDirection Ascending
.\AE-Find-WebLinks.ps1 -Command Maintain -Files '.\links.txt','.\other-links.txt' -DeduplicateWhen End -SortWhen End
```

`Maintain` runs whichever operations you enable with `-DeduplicateWhen` and `-SortWhen`; the example enables both. At least one must be `Start`, `End` or `Both`. Because standalone maintenance has no fetching phase, selected operations run once. `-MaintenanceFiles` is an alias for `-Files`. These operations modify the selected files in place.

During a normal extraction run, `-DeduplicateWhen` and `-SortWhen` accept `None`, `Start`, `End` or `Both`; both default to `None`. `-SortDirection` accepts `Ascending` (default) or `Descending`.

**Run-phase maintenance can modify the source URL file, output file and supplied blacklist files.** It is not restricted to the output. For explicitly targeted maintenance, use a standalone command with `-Files`. The legacy convenience options `-DeduplicateFiles` and `-SortOutput:$true` remain available.

The script uses temporary files and replacement retries for maintenance, with cleanup of recognised stale maintenance temporary files. `-MaintenanceLargeFileLimitMB` defaults to `1024` to avoid loading very large files into memory. `-IgnoreMaintenanceLargeFileLimit` explicitly bypasses that safeguard.

## Operational limits

Most runs should keep the defaults. These additional parameters expose resource and file-operation controls:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `-MaxPageContentMB` | `50` | Response-content size limit. |
| `-RegexTimeoutSeconds` | `10` | Regex operation timeout. |
| `-MaxUrlLength` | `8192` | URL-length limit used during normalisation and comparison. |
| `-MaintenanceLargeFileLimitMB` | `1024` | Large-file maintenance guard. |
| `-FileWriteRetryCount` | `5` | File-write retry attempts. |
| `-FileWriteRetryDelayMinMs` | `50` | Minimum write-retry delay. |
| `-FileWriteRetryDelayMaxMs` | `300` | Maximum write-retry delay. |
| `-FileMoveRetryCount` | `5` | File-replacement retry attempts. |
| `-FileMoveRetryDelayMs` | `300` | File-replacement retry delay. |
| `-ConnectionLimit` | `100` | Windows PowerShell 5.1 transport connection limit. |

`-AllowExtremeOperationalValues` bypasses the script's additional typo guardrails for intentional extreme settings; it does not remove parameter type and range validation. It is normally unnecessary. The built-in help contains the full parameter reference.

## Practical examples

### Collect download links from a bounded archive subtree

This command follows navigation pages even when their URLs do not match `*.zip*`. Only matching links are saved. Known static assets can appear in output while being skipped as pages to crawl.

```powershell
.\AE-Find-WebLinks.ps1 `
    -Source 'https://example.com/archive/' `
    -SearchPattern '*.zip*' `
    -OutputFile '.\archive-links.txt' `
    -Mode Append `
    -FollowUntilExhausted `
    -FollowScope SameHost `
    -FollowPathScope SeedPath `
    -MaxFollowPages 1000 `
    -EnforceRobotsTxt
```

### Process a URL list with logs, watchdog and one retry pass

```powershell
.\AE-Find-WebLinks.ps1 `
    -Source '.\source-urls.txt' `
    -SourceType File `
    -SearchPattern '*download*' `
    -OutputFile '.\matched-links.txt' `
    -Mode Append `
    -BlacklistFile '.\already-downloaded.txt' `
    -BlacklistScope Output `
    -LogCsv '.\run-log.csv' `
    -FailedUrlFile '.\failed-urls.txt' `
    -StuckUrlTimeoutSeconds 300 `
    -RetryFailedOnFinish
```

This runs sequentially on either supported runtime family. On PowerShell 7+, add `-ThrottleLimit 4` for concurrent sources.

### Run a parallel crawl for a limited session

PowerShell 7+:

```powershell
.\AE-Find-WebLinks.ps1 `
    -Source 'https://example.com/archive/' `
    -SearchPattern '*download*' `
    -OutputFile '.\crawl-links.txt' `
    -Mode Append `
    -FollowDepth 3 `
    -FollowScope SameHost `
    -FollowPathScope SeedPath `
    -MaxFollowPages 1000 `
    -ThrottleLimit 4 `
    -DelaySeconds 5 `
    -DelayJitterSeconds 2 `
    -MaxRunMinutes 60 `
    -EnforceRobotsTxt `
    -LogCsv '.\crawl-log.csv' `
    -FailedUrlFile '.\crawl-failed.txt' `
    -Quiet
```

To continue the saved job, rerun with the same inputs/settings and add `-Resume`.

## Exit codes and completion checks

| Code | Meaning |
| --- | --- |
| `0` | Normal command completion; can also occur after native-host Ctrl+C. It does not guarantee that every URL in a File run succeeded. |
| `1` | Runtime failure or URL failure in the applicable execution path. |
| `2` | Incomplete extraction command. |
| `3` | Runtime scheduling limit reached, with progress retained where enabled. |
| `130` | The script's cancellation handler ran. Native-host interruption can behave differently. |

For automated jobs, check the CSV statuses, failure records, totals and progress alongside the exit code. In the current code, File-mode per-URL failures do not always force a nonzero exit, and a URL-source failure can take precedence over a deadline status. Avoid treating one exit code as a complete run report.

## What's included in 1.8.0

Compared with the older documentation, the current release includes parallel crawling on PowerShell 7+, custom request headers, request-local certificate-validation control, a selectable default URL scheme, runtime scheduling limits, delay jitter, quiet mode and version reporting.

The release also integrates existing resumable crawl journals and bounded recovery controls with the parallel scheduler. Fixes cover watchdog configuration, byte-order-mark-aware response decoding, slow-trickle request deadlines, duplicate occurrence handling, incomplete-command validation, HTTP 400/405 retries, retry-pass exit status and UTF-8 output without a BOM.

See the [1.8.0 release notes](https://github.com/mukkino/AE-Find-WebLinks/releases/tag/v1.8.0) for the full changelog and documented caveats.

## Complete parameter reference

All **74 script-defined parameters** in version **1.8.0** are documented below. Each entry gives its purpose, declared type/default, accepted values, aliases where present, a complete example command and the relevant dependencies, overrides or conflicts found in the code. PowerShell's own host/common parameters are outside this list.

Examples use placeholder websites and local files. Replace them with your own sources; the `example.com` paths illustrate syntax and are not a promise of downloadable content. File examples require the named input/blacklist files to exist. Maintenance examples modify the selected files. Resume examples assume the corresponding job has already created compatible state. Parallel examples require PowerShell 7+.

Each example is an independent alternative, not a sequence to run against the same output/progress files. Commands are shown as single lines for copying. Parameters accept case-insensitive names and ValidateSet choices. Integer parameters remain limited to the declared range even with `-AllowExtremeOperationalValues`. “Guardrail” means the additional maximum enforced unless that switch is supplied, not an alternative default. Zero only disables a feature where explicitly stated.

### Parameter index

| Parameter | Default |
| --- | --- |
| [`-Source`](#parameter-source) | `not set` |
| [`-SearchPattern`](#parameter-searchpattern) | `not set` |
| [`-SearchPatterns`](#parameter-searchpatterns) | `not set` |
| [`-SearchMode`](#parameter-searchmode) | `"Any"` |
| [`-ExcludePattern`](#parameter-excludepattern) | `not set` |
| [`-ExcludePatterns`](#parameter-excludepatterns) | `not set` |
| [`-ExcludeMode`](#parameter-excludemode) | `"Any"` |
| [`-OutputFile`](#parameter-outputfile) | `not set` |
| [`-Mode`](#parameter-mode) | `"Append"` |
| [`-SourceType`](#parameter-sourcetype) | `"Url"` |
| [`-RetryCount`](#parameter-retrycount) | `3` |
| [`-WaitSeconds`](#parameter-waitseconds) | `30` |
| [`-TimeoutSeconds`](#parameter-timeoutseconds) | `120` |
| [`-StuckUrlTimeoutSeconds`](#parameter-stuckurltimeoutseconds) | `"300"` |
| [`-DelaySeconds`](#parameter-delayseconds) | `5` |
| [`-FollowDepth`](#parameter-followdepth) | `0` |
| [`-FollowUntilExhausted`](#parameter-followuntilexhausted) | `off` |
| [`-FollowScope`](#parameter-followscope) | `"SameDomain"` |
| [`-FollowPathScope`](#parameter-followpathscope) | `"Any"` |
| [`-FollowSubdomains`](#parameter-followsubdomains) | `$false` |
| [`-MaxSubdomainDepth`](#parameter-maxsubdomaindepth) | `1` |
| [`-MaxFollowPages`](#parameter-maxfollowpages) | `1000` |
| [`-EnforceRobotsTxt`](#parameter-enforcerobotstxt) | `off` |
| [`-RobotsUserAgent`](#parameter-robotsuseragent) | `"AE-Find-WebLinks"` |
| [`-SecondFetch`](#parameter-secondfetch) | `$true` |
| [`-SecondFetchWait`](#parameter-secondfetchwait) | `5` |
| [`-KeepDuplicates`](#parameter-keepduplicates) | `off` |
| [`-NoDuplicates`](#parameter-noduplicates) | `$true` |
| [`-BlacklistFile`](#parameter-blacklistfile) | `not set` |
| [`-BlacklistScope`](#parameter-blacklistscope) | `"Both"` |
| [`-ThrottleLimit`](#parameter-throttlelimit) | `1` |
| [`-Resume`](#parameter-resume) | `off` |
| [`-DeduplicateFiles`](#parameter-deduplicatefiles) | `off` |
| [`-KeepFragments`](#parameter-keepfragments) | `off` |
| [`-StripRegexBeforeEvaluation`](#parameter-stripregexbeforeevaluation) | `off` |
| [`-LinkEvaluationStripRegex`](#parameter-linkevaluationstripregex) | `not set` |
| [`-Proxy`](#parameter-proxy) | `not set` |
| [`-SortOutput`](#parameter-sortoutput) | `$false` |
| [`-Command`](#parameter-command) | `"Run"` |
| [`-Files`](#parameter-files) | `not set` |
| [`-SortDirection`](#parameter-sortdirection) | `"Ascending"` |
| [`-DeduplicateWhen`](#parameter-deduplicatewhen) | `"None"` |
| [`-SortWhen`](#parameter-sortwhen) | `"None"` |
| [`-UserAgent`](#parameter-useragent) | `browser-style string; see entry` |
| [`-ProgressFile`](#parameter-progressfile) | `not set` |
| [`-LogCsv`](#parameter-logcsv) | `not set` |
| [`-FailedUrlFile`](#parameter-failedurlfile) | `not set` |
| [`-LogMode`](#parameter-logmode) | `"Append"` |
| [`-FailedUrlMode`](#parameter-failedurlmode) | `"Append"` |
| [`-RetryFailedOnFinish`](#parameter-retryfailedonfinish) | `off` |
| [`-MaintenanceLargeFileLimitMB`](#parameter-maintenancelargefilelimitmb) | `1024` |
| [`-IgnoreMaintenanceLargeFileLimit`](#parameter-ignoremaintenancelargefilelimit) | `off` |
| [`-MaxPageContentMB`](#parameter-maxpagecontentmb) | `50` |
| [`-RegexTimeoutSeconds`](#parameter-regextimeoutseconds) | `10` |
| [`-MaxUrlLength`](#parameter-maxurllength) | `8192` |
| [`-MaxRedirects`](#parameter-maxredirects) | `10` |
| [`-MaxRetryAfterSeconds`](#parameter-maxretryafterseconds) | `300` |
| [`-FileWriteRetryCount`](#parameter-filewriteretrycount) | `5` |
| [`-FileWriteRetryDelayMinMs`](#parameter-filewriteretrydelayminms) | `50` |
| [`-FileWriteRetryDelayMaxMs`](#parameter-filewriteretrydelaymaxms) | `300` |
| [`-FileMoveRetryCount`](#parameter-filemoveretrycount) | `5` |
| [`-FileMoveRetryDelayMs`](#parameter-filemoveretrydelayms) | `300` |
| [`-ConnectionLimit`](#parameter-connectionlimit) | `100` |
| [`-AllowExtremeOperationalValues`](#parameter-allowextremeoperationalvalues) | `off` |
| [`-HighFailureRatePercent`](#parameter-highfailureratepercent) | `50` |
| [`-Header`](#parameter-header) | `not set` |
| [`-SkipCertificateCheck`](#parameter-skipcertificatecheck) | `off` |
| [`-DefaultScheme`](#parameter-defaultscheme) | `"https"` |
| [`-Quiet`](#parameter-quiet) | `off` |
| [`-MaxRunMinutes`](#parameter-maxrunminutes) | `0` |
| [`-DelayJitterSeconds`](#parameter-delayjitterseconds) | `0` |
| [`-Help`](#parameter-help) | `off` |
| [`-InteractiveHelp`](#parameter-interactivehelp) | `off` |
| [`-Version`](#parameter-version) | `off` |

### Parameter Source

**`-Source`** — The HTTP/HTTPS page to fetch, or the text file containing source URLs. Bare hosts are normalised using DefaultScheme. Positional argument 0.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source 'https://example.com/archive/'
```

**Use with other options:** Required for Run. Use SourceType File for a file path; file mode is not inferred from the extension. With crawling, sources become seeds. Ignored by standalone maintenance. Source URL/private-network validation and file readability checks apply.

### Parameter SearchPattern

**`-SearchPattern`** — One whole-URL, case-insensitive wildcard include pattern. Use * around substrings and ? for one character; this is not a regular expression. Positional argument 1.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -OutputFile '.\links.txt' -Mode Append -SearchPattern '*download*'
```

**Use with other options:** Required unless SearchPatterns supplies a nonblank pattern. When both are supplied, their patterns are combined, not overridden. SearchMode applies to the combined set. Does not restrict crawl discovery.

### Parameter SearchPatterns

**`-SearchPatterns`** — An array of include patterns, with blank entries discarded and repeated patterns removed.

**Type:** `string[]`. **Default:** `not set`.  
**Accepted values:** one or more strings.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -OutputFile '.\links.txt' -Mode Append -SearchPatterns '*.zip*','*.lha*' -SearchMode Any
```

**Use with other options:** Can replace or supplement SearchPattern. Any accepts one match; All requires every pattern. Do not combine mutually exclusive extensions with All unless you genuinely expect both substrings in one URL.

### Parameter SearchMode

**`-SearchMode`** — Select how the effective include-pattern list is combined: Any accepts at least one match; All requires every match.

**Type:** `string`. **Default:** `"Any"`.  
**Accepted values:** `Any`, `All`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -OutputFile '.\links.txt' -Mode Append -SearchPatterns '*archive*','*.zip*' -SearchMode All
```

**Use with other options:** Applies jointly to SearchPattern and SearchPatterns. With one pattern, Any and All behave the same. Exclusions are applied afterwards, so an included link can still be rejected.

### Parameter ExcludePattern

**`-ExcludePattern`** — One wildcard pattern for rejecting otherwise matching output links.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -OutputFile '.\links.txt' -Mode Append -SearchPattern '*' -ExcludePattern '*preview*'
```

**Use with other options:** Combines with ExcludePatterns. ExcludeMode applies to the combined list. It does not stop fetching or following the URL; use crawl scope or input blacklists for fetch restrictions.

### Parameter ExcludePatterns

**`-ExcludePatterns`** — An array of output-rejection wildcard patterns.

**Type:** `string[]`. **Default:** `not set`.  
**Accepted values:** one or more strings.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -OutputFile '.\links.txt' -Mode Append -SearchPattern '*' -ExcludePatterns '*preview*','*thumbnail*' -ExcludeMode Any
```

**Use with other options:** May be used with ExcludePattern; nonblank patterns are merged. Any rejects on one match. All rejects only when all exclusions match a URL. These are wildcards, not regex expressions.

### Parameter ExcludeMode

**`-ExcludeMode`** — Select Any or All logic for the effective exclusion list.

**Type:** `string`. **Default:** `"Any"`.  
**Accepted values:** `Any`, `All`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -ExcludePatterns '*preview*','*.jpg*' -ExcludeMode All
```

**Use with other options:** Has no filtering effect without exclusions. All in the example rejects links containing both preview and .jpg; it does not mean reject either one. Include checks still happen first.

### Parameter OutputFile

**`-OutputFile`** — Destination text file for matching URLs, one per line. Positional argument 2.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -Mode Append -OutputFile '.\download-links.txt'
```

**Use with other options:** Required for Run. Mode controls append/overwrite. Must not collide with the source file, blacklists, CSV, failed-URL file or progress file. Supplying this path alone does not download the linked files.

### Parameter Mode

**`-Mode`** — Select Append to retain previous output or New to create/overwrite it. Positional argument 3.

**Type:** `string`. **Default:** `"Append"`.  
**Accepted values:** `Append`, `New`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode New
```

**Use with other options:** Resume overrides New to Append. NoDuplicates controls whether existing output suppresses repeats. Mode does not control CSV/failure-file modes; use LogMode and FailedUrlMode separately.

### Parameter SourceType

**`-SourceType`** — Choose Url for a single page or File for a file containing source URL tokens. Positional argument 4.

**Type:** `string`. **Default:** `"Url"`.  
**Accepted values:** `Url`, `File`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File
```

**Use with other options:** File is required for URL-list processing. Both types support crawling. Resume with Url requires crawling. Parallel processing needs either File mode or a crawl; one non-crawl Url cannot be parallelised.

### Parameter RetryCount

**`-RetryCount`** — Maximum HTTP attempts in each request retry loop, including the initial attempt. Also bounds the number of whole-URL watchdog runs. A value of 1 allows one attempt and one watchdog run.

**Type:** `int`. **Default:** `3`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `100`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -RetryCount 3
```

**Use with other options:** Not a total network-request cap: redirects, second fetches, robots checks and watchdog restarts can add requests. Permanent HTTP errors can fail early. Works with WaitSeconds, TimeoutSeconds and StuckUrlTimeoutSeconds. RetryFailedOnFinish is a separate extra pass.

### Parameter WaitSeconds

**`-WaitSeconds`** — Configured delay between ordinary HTTP retry attempts, in seconds. Zero retries immediately when a retry remains.

**Type:** `int`. **Default:** `30`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -RetryCount 3 -WaitSeconds 10
```

**Use with other options:** Distinct from DelaySeconds and SecondFetchWait. An accepted Retry-After wait can replace this delay. Wait time consumes the active stuck-URL watchdog budget. With RetryCount 1 there is normally no ordinary inter-attempt wait.

### Parameter TimeoutSeconds

**`-TimeoutSeconds`** — Deadline for each HTTP attempt, including response headers and body reading.

**Type:** `int`. **Default:** `120`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `86400`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -TimeoutSeconds 60
```

**Use with other options:** Does not limit an entire multi-URL job. StuckUrlTimeoutSeconds can shorten an attempt to the remaining watchdog budget. Retries may start additional attempts; MaxRunMinutes controls scheduling rather than this deadline.

### Parameter StuckUrlTimeoutSeconds

**`-StuckUrlTimeoutSeconds`** — Whole-URL watchdog duration in seconds. On expiry, restart that URL's processing, bounded by RetryCount. Accepts a positive integer string, or 0/Disabled/Disable/Off/None/False to disable (case-insensitive).

**Type:** `string`. **Default:** `"300"`.  
**Accepted values:** string. **Normal guardrail:** `604800`.  
**Aliases:** `-SameLinkTimeoutSeconds`, `-UrlWatchdogSeconds`, `-StuckLinkTimeoutSeconds`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -StuckUrlTimeoutSeconds 600
```

**Use with other options:** Covers supported request, wait and extraction checkpoints, not a guaranteed process-kill deadline. Long WaitSeconds or SecondFetchWait values can consume the budget. RetryCount 1 gives no additional watchdog restart. Empty, negative or unparseable values fail validation.

### Parameter DelaySeconds

**`-DelaySeconds`** — Base delay between different source/crawl URL starts. In parallel mode it spaces scheduling across the pool.

**Type:** `int`. **Default:** `5`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -DelaySeconds 2
```

**Use with other options:** Can combine with DelayJitterSeconds, including jitter when base delay is 0. It is not the retry or second-fetch delay. Has no inter-source effect for one URL without crawling; it does not mean one global delay before every internal HTTP request.

### Parameter FollowDepth

**`-FollowDepth`** — Maximum link-hop depth: 0 scans only supplied sources; 1 includes discovered links one hop away; positive values extend depth. -1 means until exhausted.

**Type:** `int`. **Default:** `0`.  
**Accepted values:** `-1` through `2147483647`. **Normal guardrail:** `10`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 2 -FollowScope SameHost
```

**Use with other options:** A positive value conflicts with FollowUntilExhausted and causes an error. Zero does not disable crawling when FollowUntilExhausted is present. All crawl bounds and MaxFollowPages still apply. Values above 10 require AllowExtremeOperationalValues.

### Parameter FollowUntilExhausted

**`-FollowUntilExhausted`** — Enable crawling until no permitted unseen candidates remain, without a fixed hop-depth limit.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-FollowToEnd`, `-UnlimitedFollowDepth`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowUntilExhausted -FollowScope SameHost -MaxFollowPages 1000
```

**Use with other options:** Cannot combine with a positive FollowDepth. Equivalent unlimited-depth intent to FollowDepth -1; all scope, path, blacklist, robots and page-count constraints still apply. It does not imply MaxFollowPages 0.

### Parameter FollowScope

**`-FollowScope`** — Choose SameDomain, SameHost or Any for crawl candidate hosts. SameDomain uses the built-in domain approximation; SameHost uses exact seed hostnames.

**Type:** `string`. **Default:** `"SameDomain"`.  
**Accepted values:** `SameDomain`, `SameHost`, `Any`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 2 -FollowScope SameHost
```

**Use with other options:** Only affects crawl discovery, not which external links may be saved from a page. FollowSubdomains and MaxSubdomainDepth only refine SameDomain. SeedPath adds a separate restriction. For multiple seeds, boundaries are built from their hosts/domains.

### Parameter FollowPathScope

**`-FollowPathScope`** — Any permits paths allowed by host rules; SeedPath restricts candidates to seed path subtrees using segment-aware checks.

**Type:** `string`. **Default:** `"Any"`.  
**Accepted values:** `Any`, `SeedPath`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source 'https://example.com/archive/' -FollowDepth 2 -FollowScope SameHost -FollowPathScope SeedPath
```

**Use with other options:** Ignored with a warning when crawling is disabled. With FollowScope Any, SeedPath still binds paths to seed hosts, so it does not allow the same path on arbitrary external hosts. Regex stripping can change the evaluated seed boundary. Query strings/fragments do not define this boundary.

### Parameter FollowSubdomains

**`-FollowSubdomains`** — Allow additional subdomains in SameDomain crawling. Use Boolean syntax with an explicit true or false value.

**Type:** `bool`. **Default:** `$false`.  
**Accepted values:** `$true` or `$false` (supply an explicit Boolean value).

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 2 -FollowScope SameDomain -FollowSubdomains:$true
```

**Use with other options:** Does not broaden SameHost; Any already ignores domain restrictions. MaxSubdomainDepth limits newly permitted subdomains. Seed, apex and www handling still applies when false. Has no effect without crawling.

### Parameter MaxSubdomainDepth

**`-MaxSubdomainDepth`** — Limit additional subdomain levels below the approximate root domain. 1 permits direct subdomains; 2 permits two levels; 0 removes this depth limit.

**Type:** `int`. **Default:** `1`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `100`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 2 -FollowScope SameDomain -FollowSubdomains:$true -MaxSubdomainDepth 2
```

**Use with other options:** Only meaningful with SameDomain and FollowSubdomains true. Does not limit URL path depth (use FollowDepth/FollowPathScope). Explicit seed hosts have their own allowance; this is not a blanket ban on deep seed hosts.

### Parameter MaxFollowPages

**`-MaxFollowPages`** — Cap the crawl's scheduled page count, including seeds. Zero removes this page cap.

**Type:** `int`. **Default:** `1000`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `1000000`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 3 -MaxFollowPages 500
```

**Use with other options:** Only used in crawl mode. Does not cap saved links or individual HTTP requests. Reaching the cap can leave discovery incomplete even with FollowUntilExhausted. This value is in crawl resume signatures, so raising it can invalidate existing state.

### Parameter EnforceRobotsTxt

**`-EnforceRobotsTxt`** — Opt in to robots.txt checks for source pages, crawl pages and redirect targets.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 1 -EnforceRobotsTxt -RobotsUserAgent 'AE-Find-WebLinks'
```

**Use with other options:** Works without crawling too. RobotsUserAgent chooses matching groups independently of HTTP UserAgent. 4xx robots responses allow access; unavailable/server-error policies fail closed. Unsupported Crawl-delay is ignored; use DelaySeconds. The policy cache is per origin.

### Parameter RobotsUserAgent

**`-RobotsUserAgent`** — Product token used to select robots.txt User-agent groups.

**Type:** `string`. **Default:** `"AE-Find-WebLinks"`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -EnforceRobotsTxt -RobotsUserAgent 'AE-Find-WebLinks'
```

**Use with other options:** Only affects robots matching when enforcement is enabled. Does not set the HTTP User-Agent header. Empty strings are rejected; whitespace-only values are rejected when enforcement is enabled. Included in the resume signature.

### Parameter SecondFetch

**`-SecondFetch`** — Enable or disable the second request for a page, keeping the larger response. Requires explicit Boolean syntax.

**Type:** `bool`. **Default:** `$true`.  
**Accepted values:** `$true` or `$false` (supply an explicit Boolean value).

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -SecondFetch:$false
```

**Use with other options:** SecondFetchWait only applies when enabled. Adds HTTP traffic and consumes watchdog time. It does not execute JavaScript. Changing this Boolean invalidates the run signature on resume.

### Parameter SecondFetchWait

**`-SecondFetchWait`** — Delay before a second fetch, in seconds. Zero removes the wait.

**Type:** `int`. **Default:** `5`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -SecondFetch:$true -SecondFetchWait 2
```

**Use with other options:** No effect when SecondFetch is false. Separate from DelaySeconds and WaitSeconds. Long values may cause the stuck-URL watchdog to expire before the second request.

### Parameter KeepDuplicates

**`-KeepDuplicates`** — Preserve genuine repeated link occurrences within one page's matched batch.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -KeepDuplicates
```

**Use with other options:** With NoDuplicates true, repeats can be kept on their first page but all are suppressed if the URL was already in output/from an earlier page. To allow repeats across pages too, add NoDuplicates false. Deduplication maintenance can later remove retained repeats.

### Parameter NoDuplicates

**`-NoDuplicates`** — Control suppression against existing output and previously written page results. Boolean true enables it; false allows repeats across sources.

**Type:** `bool`. **Default:** `$true`.  
**Accepted values:** `$true` or `$false` (supply an explicit Boolean value).

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -NoDuplicates:$false -KeepDuplicates
```

**Use with other options:** Setting false alone does not retain within-page repeats: also use KeepDuplicates. Setting true does not clean duplicates already in a file; use maintenance for that. KeepFragments and regex stripping affect keys. Run-end deduplication may undo deliberate duplicate retention.

### Parameter BlacklistFile

**`-BlacklistFile`** — One or more exact-URL blacklist files, each containing one URL per line.

**Type:** `string[]`. **Default:** `not set`.  
**Accepted values:** one or more strings.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -BlacklistFile '.\blocked.txt','.\already-downloaded.txt' -BlacklistScope Both
```

**Use with other options:** Not wildcard or whole-domain blocking. BlacklistScope selects fetch/output use. Missing files warn and are skipped. Output blacklist checks use evaluation stripping when enabled. Run-phase maintenance can rewrite blacklist files. Paths must not collide with writable output/log/progress/failure files.

### Parameter BlacklistScope

**`-BlacklistScope`** — Input skips blacklisted input/crawl URLs; Output suppresses matching extracted output; Both applies both.

**Type:** `string`. **Default:** `"Both"`.  
**Accepted values:** `Input`, `Output`, `Both`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -BlacklistFile '.\already-downloaded.txt' -BlacklistScope Output
```

**Use with other options:** No blacklist effect without successfully loaded BlacklistFile entries. Output does not prevent fetching; Input does not prevent a blacklisted URL being saved as an extracted link. Signed setting for resume.

### Parameter ThrottleLimit

**`-ThrottleLimit`** — Maximum concurrent URL workers. 1 is sequential; values above 1 require PowerShell 7+.

**Type:** `int`. **Default:** `1`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `64`.  
**Aliases:** `-Parallel`, `-Workers`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -ThrottleLimit 4
```

**Use with other options:** Supported for File runs and crawling. Windows PowerShell 5.1 rejects values above 1. A single non-crawl URL resets it to 1 with a warning on a supporting runtime. DelaySeconds/Jitter space starts. ConnectionLimit does not select worker count.

### Parameter Resume

**`-Resume`** — Continue a compatible saved File-mode job or crawl instead of silently replacing progress.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -Resume
```

**Use with other options:** Non-crawl Url mode rejects this. Forces Mode, LogMode and FailedUrlMode from New to Append. Matching signature and retained output are required when saved state exists. Missing progress is not proof of completion and may result in a fresh journal rather than recovery. Use the original run inputs/settings.

### Parameter DeduplicateFiles

**`-DeduplicateFiles`** — Legacy convenience switch: maps DeduplicateWhen None to Start, deduplicating the run's source/output/blacklist files before processing.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -DeduplicateFiles
```

**Use with other options:** An explicit non-None DeduplicateWhen wins. With SortOutput true and SortWhen None, also triggers start-phase sorting of involved files plus legacy end sorting of output. Can change inputs, not just output. Use explicit timing parameters for clarity.

### Parameter KeepFragments

**`-KeepFragments`** — Keep #fragment suffixes in output and distinguish them in URL-aware deduplication and blacklist keys.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -KeepFragments
```

**Use with other options:** Does not stop other normalisation, including case-insensitive and HTTP/HTTPS-equivalent keys. Does not change SeedPath's fragment-free path boundary. Applies to standalone deduplication too and is signed for resume.

### Parameter StripRegexBeforeEvaluation

**`-StripRegexBeforeEvaluation`** — Enable removal of regex-matched text before output matching, exclusions, output-blacklist checks, deduplication and writing.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-UseEvaluationStripRegex`, `-EnableEvaluationStripRegex`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -StripRegexBeforeEvaluation -LinkEvaluationStripRegex '/\d+$'
```

**Use with other options:** Requires a nonblank valid LinkEvaluationStripRegex or errors. Does not rewrite the actual source/crawl URL fetched. Can change the evaluated seed path used by SeedPath. Uses RegexTimeoutSeconds. Both this flag and regex text are signed for resume.

### Parameter LinkEvaluationStripRegex

**`-LinkEvaluationStripRegex`** — The .NET regular expression whose matches are removed from a URL's evaluated form. Default regex matching is case-sensitive; use inline flags if needed.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.  
**Aliases:** `-EvaluationStripRegex`, `-LinkEvaluationRegex`, `-IgnoreRegexForEvaluation`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -StripRegexBeforeEvaluation -LinkEvaluationStripRegex '/\d+$'
```

**Use with other options:** Supplying this without StripRegexBeforeEvaluation enables stripping automatically with a warning. Invalid regex fails. An unanchored expression removes matching text wherever found; anchor with $ for a suffix. This is distinct from ExcludePattern, which rejects links instead of rewriting them.

### Parameter Proxy

**`-Proxy`** — Explicit absolute HTTP or HTTPS proxy URI. Optional URI user:password authentication is accepted by the parser.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Proxy 'http://proxy.example.com:8080'
```

**Use with other options:** Relative addresses, unsupported schemes and missing hosts fail. No separate ProxyCredential parameter exists. Do not put live credentials in shared commands. This does not change crawl boundaries or replace deployment testing for enterprise proxy/PAC setups.

### Parameter SortOutput

**`-SortOutput`** — Legacy Boolean option to sort output at the end when SortWhen is None.

**Type:** `bool`. **Default:** `$false`.  
**Accepted values:** `$true` or `$false` (supply an explicit Boolean value).

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -SortOutput:$true
```

**Use with other options:** Explicit non-None SortWhen takes precedence. With DeduplicateFiles and SortWhen None, also sorts involved source/output/blacklist files at start and output at end. Sorting alone does not deduplicate. Use SortDirection for order.

### Parameter Command

**`-Command`** — Select Run for extraction, Deduplicate or Sort for a single maintenance operation, or Maintain for selected combined operations.

**Type:** `string`. **Default:** `"Run"`.  
**Accepted values:** `Run`, `Deduplicate`, `Sort`, `Maintain`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Maintain -Files '.\links.txt' -DeduplicateWhen End -SortWhen End
```

**Use with other options:** Non-Run commands require Files and do not fetch URLs. Maintain additionally needs non-None DeduplicateWhen and/or SortWhen. Run inputs/filters do not select maintenance targets. Shared parameter validation can still reject malformed or conflicting options before maintenance begins.

### Parameter Files

**`-Files`** — Explicit list of files to modify during standalone maintenance.

**Type:** `string[]`. **Default:** `not set`.  
**Accepted values:** one or more strings.  
**Aliases:** `-MaintenanceFiles`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Deduplicate -Files '.\links.txt','.\other-links.txt'
```

**Use with other options:** Required when Command is not Run. Ignored with a warning for Command Run; normal run maintenance chooses source/output/blacklist files instead. Existing selected files are modified in place; missing files warn and are skipped.

### Parameter SortDirection

**`-SortDirection`** — Ascending or Descending order for sorting operations.

**Type:** `string`. **Default:** `"Ascending"`.  
**Accepted values:** `Ascending`, `Descending`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Sort -Files '.\links.txt' -SortDirection Descending
```

**Use with other options:** Has no effect unless sorting is selected by Command Sort, Maintain with SortWhen, run-phase SortWhen or legacy SortOutput. Does not control crawl traversal or worker completion order.

### Parameter DeduplicateWhen

**`-DeduplicateWhen`** — Choose None, Start, End or Both for deduplication around a normal run.

**Type:** `string`. **Default:** `"None"`.  
**Accepted values:** `None`, `Start`, `End`, `Both`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -DeduplicateWhen End
```

**Use with other options:** Run phases target source/output/blacklist files. Non-None overrides the legacy DeduplicateFiles mapping. In standalone Maintain, any non-None value enables one deduplication pass. End/Both can remove repeats requested by KeepDuplicates/NoDuplicates false.

### Parameter SortWhen

**`-SortWhen`** — Choose None, Start, End or Both for sorting around a normal run.

**Type:** `string`. **Default:** `"None"`.  
**Accepted values:** `None`, `Start`, `End`, `Both`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -SortWhen End
```

**Use with other options:** Run phases target source/output/blacklist files, not only output. Non-None overrides legacy SortOutput scheduling. In Maintain, any non-None value enables one sorting pass. Sorting is independent of deduplication.

### Parameter UserAgent

**`-UserAgent`** — HTTP User-Agent string sent with page requests. Default is the browser-style string listed below.

**Type:** `string`. **Default:** `"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -UserAgent 'AE-Find-WebLinks/1.8.0'
```

**Use with other options:** Header 'User-Agent: ...' is rejected; use this parameter. RobotsUserAgent is independent. A browser-like user agent does not provide browser rendering, JavaScript execution or automatic login.

### Parameter ProgressFile

**`-ProgressFile`** — Custom progress path, replacing the derived File/crawl progress filename.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -ProgressFile '.\job.progress'
```

**Use with other options:** Default is OutputFile.progress for non-crawl File and OutputFile.crawl.progress for crawling. A path alone does not make a single non-crawl Url resumable. Existing state without Resume causes refusal. Must not collide with source/output/log/failure/blacklist paths. Keep the same path when resuming.

### Parameter LogCsv

**`-LogCsv`** — Optional per-source CSV log path, with status, counts and error details.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -LogCsv '.\run-log.csv'
```

**Use with other options:** LogMode controls append/overwrite; Resume forces append. Must not collide with source/output/blacklist/progress/failure paths. Quiet does not disable this log. A log is not a progress journal and cannot substitute for ProgressFile.

### Parameter FailedUrlFile

**`-FailedUrlFile`** — Optional tab-separated file of failed source URLs and associated error details.

**Type:** `string`. **Default:** `not set`.  
**Accepted values:** string.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FailedUrlFile '.\failed-urls.txt'
```

**Use with other options:** FailedUrlMode controls append/overwrite; Resume forces append. Must use a distinct path from the other operational files. RetryFailedOnFinish uses saved progress, not this file as its recovery database. Appended failures can remain after later successful retries.

### Parameter LogMode

**`-LogMode`** — Append to or overwrite/create the CSV log independently of output mode.

**Type:** `string`. **Default:** `"Append"`.  
**Accepted values:** `Append`, `New`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -LogCsv '.\run-log.csv' -LogMode New
```

**Use with other options:** Only useful when LogCsv is supplied. Resume and the automatic retry pass force Append. Mode New does not automatically set LogMode New.

### Parameter FailedUrlMode

**`-FailedUrlMode`** — Append to or overwrite/create the failed-URL file independently of output mode.

**Type:** `string`. **Default:** `"Append"`.  
**Accepted values:** `Append`, `New`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FailedUrlFile '.\failed-urls.txt' -FailedUrlMode New
```

**Use with other options:** Only useful when FailedUrlFile is supplied. Resume and the automatic retry pass force Append. Failure logs can contain historical failed attempts even after success.

### Parameter RetryFailedOnFinish

**`-RetryFailedOnFinish`** — After a run with failures, launch one additional resume pass over unfinished work when saved progress is available.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-AutoRetryFailed`, `-RetryFailedAtEnd`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -RetryFailedOnFinish
```

**Use with other options:** Requires a script path and existing progress file; otherwise warns. Does not run after MaxRunMinutes has stopped scheduling. Forces all file modes to Append and removes itself from the child invocation, preventing recursive passes. A single non-crawl URL normally lacks usable progress.

### Parameter MaintenanceLargeFileLimitMB

**`-MaintenanceLargeFileLimitMB`** — Size threshold for deduplication/sorting of files. Files larger than this are skipped with a warning and left unchanged. Zero removes the threshold.

**Type:** `int`. **Default:** `1024`.  
**Accepted values:** `0` through `2147483647`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Deduplicate -Files '.\links.txt' -MaintenanceLargeFileLimitMB 256
```

**Use with other options:** Only affects maintenance, not page responses or output growth. IgnoreMaintenanceLargeFileLimit overrides it. Deduplication tracks seen keys and sorting loads data, so removing the threshold does not make maintenance memory-free.

### Parameter IgnoreMaintenanceLargeFileLimit

**`-IgnoreMaintenanceLargeFileLimit`** — Bypass MaintenanceLargeFileLimitMB for maintenance operations.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Sort -Files '.\links.txt' -IgnoreMaintenanceLargeFileLimit
```

**Use with other options:** Equivalent to disabling that guard, even when a nonzero limit is supplied. Does not affect MaxPageContentMB or any other limit. Use only when the machine has enough resources for the file.

### Parameter MaxPageContentMB

**`-MaxPageContentMB`** — Maximum response body size admitted by the transport/content checks. Zero disables the size guard.

**Type:** `int`. **Default:** `50`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `1024`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -MaxPageContentMB 25
```

**Use with other options:** Independent of maintenance size limits and crawl page count. The response limit also matters to robots fetching. A separate built-in robots parsing limit is not a public parameter. A smaller limit may reject otherwise reachable pages; increasing it does not change timeouts.

### Parameter RegexTimeoutSeconds

**`-RegexTimeoutSeconds`** — Timeout for regex matching operations. Zero selects an infinite match timeout and emits a warning.

**Type:** `int`. **Default:** `10`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `3600`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -RegexTimeoutSeconds 5
```

**Use with other options:** Also used for LinkEvaluationStripRegex. It is not an HTTP timeout. A stuck regex with no timeout can prevent timely cancellation/watchdog handling; retain a finite value for normal use.

### Parameter MaxUrlLength

**`-MaxUrlLength`** — Maximum URL length accepted during normalisation. Overlong candidates are discarded; some fallback comparison-key handling truncates them. Zero disables the length guard.

**Type:** `int`. **Default:** `8192`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `1048576`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -MaxUrlLength 4096
```

**Use with other options:** Independent of response-size limits. Too-small values can discard legitimate long URLs. Does not mean truncate every saved URL into a usable shorter URL. Influences normalisation and key creation rather than crawl hop depth.

### Parameter MaxRedirects

**`-MaxRedirects`** — Maximum permitted HTTP/meta-refresh redirect hops during request handling.

**Type:** `int`. **Default:** `10`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `100`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -MaxRedirects 5
```

**Use with other options:** Minimum is 1, so 0 is rejected rather than meaning no redirects. Separate from FollowDepth, which counts discovered-page hops. Redirect targets still receive private/internal checks and optional robots enforcement. RetryCount is not this limit.

### Parameter MaxRetryAfterSeconds

**`-MaxRetryAfterSeconds`** — Maximum server Retry-After delay that will be honoured for HTTP 429/503. Zero ignores that header and uses ordinary retry-delay handling.

**Type:** `int`. **Default:** `300`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -MaxRetryAfterSeconds 60 -WaitSeconds 10
```

**Use with other options:** If the requested delay exceeds this threshold, the code falls back to ordinary retry handling; it does not clamp the server value to the threshold. Accepted waits consume watchdog time. Both numeric and future HTTP-date forms are handled.

### Parameter FileWriteRetryCount

**`-FileWriteRetryCount`** — Maximum attempts for supported file writes, including the first attempt.

**Type:** `int`. **Default:** `5`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `100`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FileWriteRetryCount 5
```

**Use with other options:** Works with FileWriteRetryDelayMinMs/MaxMs. This is not HTTP RetryCount. Permission/read-only errors may fail immediately. Exhausted output/progress writes are fatal instead of silently marking work completed.

### Parameter FileWriteRetryDelayMinMs

**`-FileWriteRetryDelayMinMs`** — Lower bound for file-write retry delay, in milliseconds.

**Type:** `int`. **Default:** `50`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400000`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FileWriteRetryDelayMinMs 100 -FileWriteRetryDelayMaxMs 500
```

**Use with other options:** Must be less than or equal to FileWriteRetryDelayMaxMs or the command fails. Relevant only when a supported write is retried. Unrelated to request DelaySeconds.

### Parameter FileWriteRetryDelayMaxMs

**`-FileWriteRetryDelayMaxMs`** — Upper bound for file-write retry delay, in milliseconds.

**Type:** `int`. **Default:** `300`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400000`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FileWriteRetryDelayMinMs 100 -FileWriteRetryDelayMaxMs 500
```

**Use with other options:** Must be greater than or equal to FileWriteRetryDelayMinMs. If setting it below the default minimum of 50, lower MinMs too. Does not affect file-move retries.

### Parameter FileMoveRetryCount

**`-FileMoveRetryCount`** — Maximum replacement attempts when maintenance swaps a completed temporary file into place.

**Type:** `int`. **Default:** `5`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `100`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Deduplicate -Files '.\links.txt' -FileMoveRetryCount 5
```

**Use with other options:** Works with FileMoveRetryDelayMs. Does not control ordinary output appends or network requests. Relevant to maintenance replacement failures such as transient file locks.

### Parameter FileMoveRetryDelayMs

**`-FileMoveRetryDelayMs`** — Delay between retry attempts to replace a maintained file.

**Type:** `int`. **Default:** `300`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400000`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Command Sort -Files '.\links.txt' -FileMoveRetryDelayMs 500
```

**Use with other options:** Used with FileMoveRetryCount. Zero removes this delay. Separate from write-retry delay bounds and all HTTP delay settings.

### Parameter ConnectionLimit

**`-ConnectionLimit`** — Configure the .NET ServicePointManager connection limit used by the Windows PowerShell 5.1 transport.

**Type:** `int`. **Default:** `100`.  
**Accepted values:** `1` through `2147483647`. **Normal guardrail:** `10000`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -ConnectionLimit 100
```

**Use with other options:** PowerShell 7 HttpClient manages its own connections and ignores this setting for its transport. Does not enable parallelism on 5.1 or substitute for ThrottleLimit. The latter still requires PowerShell 7 for values above 1.

### Parameter AllowExtremeOperationalValues

**`-AllowExtremeOperationalValues`** — Bypass the additional per-option typo guardrails shown in the range table.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -FollowDepth 11 -FollowScope SameHost -MaxFollowPages 500 -AllowExtremeOperationalValues
```

**Use with other options:** Does not bypass ValidateRange, ValidateSet, types, logical conflicts, runtime requirements, private/internal URL checks or file-collision protection. Does not itself remove page/maintenance limits. Emits a warning.

### Parameter HighFailureRatePercent

**`-HighFailureRatePercent`** — Threshold percentage for a high-failure warning in non-crawl File runs. Zero disables the warning.

**Type:** `double`. **Default:** `50`.  
**Accepted values:** `0` through `100`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -HighFailureRatePercent 25
```

**Use with other options:** Not used as a crawl failure threshold. Only warns; it does not stop the job, retry sources or force a nonzero exit. Counts failed sources rather than the percentage of extracted links rejected by filters.

### Parameter Header

**`-Header`** — One or more additional HTTP headers written as Name: value strings. Duplicate header names use the later supplied value.

**Type:** `string[]`. **Default:** `not set`.  
**Accepted values:** one or more strings.  
**Aliases:** `-Headers`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Header 'Accept-Language: en-GB,en;q=0.9','Referer: https://example.com/'
```

**Use with other options:** Rejects malformed names/entries and User-Agent (use UserAgent). Headers are run-wide, not scoped to one origin, so sensitive headers need care with redirects, robots requests and wider crawls. Transport-specific header restrictions can still apply. This is not a login/session manager.

### Parameter SkipCertificateCheck

**`-SkipCertificateCheck`** — Disable TLS certificate validation for the requests in this run; the transport setting is request-local.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-Insecure`, `-IgnoreCertificateErrors`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -SkipCertificateCheck
```

**Use with other options:** No effect on plain HTTP. Reduces HTTPS authentication and does not solve login, JavaScript or robots restrictions. Can be combined with normal run controls; it is never enabled implicitly by a proxy or custom UserAgent.

### Parameter DefaultScheme

**`-DefaultScheme`** — Select https or http as the scheme assumed for bare-host input and applicable scheme-less URL normalisation.

**Type:** `string`. **Default:** `"https"`.  
**Accepted values:** `https`, `http`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source 'example.com/archive/' -DefaultScheme http
```

**Use with other options:** Does not force an explicit https URL to http or vice versa. Does not enable non-HTTP schemes. Changes normalisation, not TLS certificate validation or crawl scope.

### Parameter Quiet

**`-Quiet`** — Reduce detailed console chatter while keeping per-URL summaries, failures, warnings and totals.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-q`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Quiet -LogCsv '.\run-log.csv'
```

**Use with other options:** Does not suppress CSV/failure files and does not turn the script into a silent pipeline returning only URLs. Saved output is still controlled by OutputFile.

### Parameter MaxRunMinutes

**`-MaxRunMinutes`** — Stop scheduling new URLs after this many minutes; zero disables the runtime scheduling limit.

**Type:** `int`. **Default:** `0`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `525600`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -MaxRunMinutes 30
```

**Use with other options:** Active work can outlast the scheduling deadline. Keep progress for Resume. Deadline stops normally use code 3, subject to error-path precedence. RetryFailedOnFinish is skipped after a deadline stop. Separate from request and watchdog timeouts.

### Parameter DelayJitterSeconds

**`-DelayJitterSeconds`** — Add a random extra interval from zero up to the specified seconds to inter-URL waits.

**Type:** `int`. **Default:** `0`.  
**Accepted values:** `0` through `2147483647`. **Normal guardrail:** `86400`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -SearchPattern '*download*' -OutputFile '.\links.txt' -Mode Append -Source '.\source-urls.txt' -SourceType File -DelaySeconds 2 -DelayJitterSeconds 3
```

**Use with other options:** Works even when DelaySeconds is 0. Does not randomise WaitSeconds or SecondFetchWait. Applies to file/crawl scheduling, not one independent initial page request. Zero disables jitter.

### Parameter Help

**`-Help`** — Print the built-in usage, options, examples and caveats, then exit.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-h`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Help
```

**Use with other options:** Does not run extraction even if source/output options are present. Version takes precedence if both are set; Help takes precedence over InteractiveHelp. Parameter binding still rejects invalid types or ValidateSet/ValidateRange values.

### Parameter InteractiveHelp

**`-InteractiveHelp`** — Open the guided command builder, including options to save or run a generated command.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.  
**Aliases:** `-Interactive`.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -InteractiveHelp
```

**Use with other options:** Use as a standalone entry point rather than expecting other flags to be an automatically executed job. Version and Help take precedence. The interactive workflow itself may offer execution after gathering answers.

### Parameter Version

**`-Version`** — Print application version and PowerShell host, then exit.

**Type:** `switch`. **Default:** `off`.  
**Accepted values:** switch: present or omitted; explicit `:$false` also accepted.

**Usage example:**

```powershell
.\AE-Find-WebLinks.ps1 -Version
```

**Use with other options:** Highest-priority entry gate: combined Help/InteractiveHelp or extraction options do not launch a run. PowerShell parameter binding occurs before this gate, so syntactically invalid argument values can still fail.

## Parameter compatibility and precedence

These distinctions matter: some combinations are **rejected**, some are **accepted but ignored**, and others **change or override another option**. A parameter having no effect is not necessarily an error.

### Rejected combinations and missing dependencies

| Combination or condition | Actual behaviour | How to use it correctly |
| --- | --- | --- |
| Positive `-FollowDepth` plus `-FollowUntilExhausted` | Error before the run. | Choose bounded depth or unlimited-depth mode. |
| `-ThrottleLimit` greater than 1 on Windows PowerShell 5.1 | Error. | Use `1` or run under PowerShell 7+. |
| `-Resume` with `-SourceType Url` and no crawling | Error. | Resume a File job or enable the original crawl mode. |
| `-StripRegexBeforeEvaluation` without a nonblank regex | Error. | Supply `-LinkEvaluationStripRegex`. |
| Invalid `-LinkEvaluationStripRegex` | Regex compilation error. | Supply a valid .NET regex; quote it as a string. |
| `-FileWriteRetryDelayMinMs` greater than `-FileWriteRetryDelayMaxMs` | Error. | Set minimum no higher than maximum. |
| `-Header 'User-Agent: ...'` | Error. | Use `-UserAgent`. |
| Malformed header or non-HTTP/HTTPS explicit proxy | Error when validated. | Use `Name: value` headers and an absolute HTTP/HTTPS proxy URI. |
| Non-Run `-Command` without `-Files` | Error. | Supply the maintenance target file(s). |
| `-Command Maintain` with both timing settings `None` | Error after legacy-option mapping. | Set `-DeduplicateWhen End`, `-SortWhen End`, or both. |
| Run without source, output or any nonblank include pattern | Exit `2`. | Supply all three; use `-SearchPattern '*'` to include all links. |
| Existing File/crawl progress without `-Resume` | Refuses to start a fresh run over it. | Resume, deliberately choose another progress path, or intentionally restart with old state removed. |
| Resume with an incompatible signature | Refuses the saved state. | Restore original signed settings or start a separate job. |
| Resume with existing state but missing output, or completed state and empty output | Refuses to skip completed work whose results may be lost. | Restore the output or deliberately restart; this can also affect jobs whose completed pages produced no matches. |
| An operational value over its normal guardrail | Error. | Correct the value, or intentionally add `-AllowExtremeOperationalValues`. |
| Value outside its declared type/range/set | PowerShell binding/validation error. | Use an accepted value; the extreme-value switch cannot bypass this. |
| Conflicting operational file paths | Error. | Give source, output, progress, logs and failure records distinct appropriate paths. |

The collision checks specifically reject output versus source/blacklists, logs/failures versus source/output/blacklists/each other, and progress versus source/output/log/failure/blacklists. Do not use maintenance target selection as a way to share writable operational files between concurrent runs.

### Automatic overrides and combinations that work

| Combination | Result |
| --- | --- |
| `-SearchPattern` plus `-SearchPatterns` | Merges nonblank patterns, removes repeats, applies one SearchMode. |
| `-ExcludePattern` plus `-ExcludePatterns` | Merges nonblank patterns, removes repeats, applies one ExcludeMode. |
| `-LinkEvaluationStripRegex` without the enabling switch | Warns and automatically enables stripping, even if the switch was explicitly false. |
| `-Resume` plus any `New` file mode | Forces output, CSV and failure modes to Append. |
| `-RetryFailedOnFinish` launching a pass | Enables Resume, forces Append modes, removes its own retry switch. |
| `-FollowUntilExhausted` plus `-FollowDepth 0` | Crawling is enabled with unlimited hop depth; 0 does not cancel the switch. |
| Unlimited hop depth plus `-MaxFollowPages 1000` | Still stops scheduling at the page cap. |
| `-FollowScope Any` plus `-FollowPathScope SeedPath` | Seed paths remain tied to seed hosts; this is not unrestricted external-domain crawling. |
| `-KeepDuplicates` plus default `-NoDuplicates:$true` | Keeps within-page repeats only while that key is not already present from prior output/pages. |
| `-KeepDuplicates -NoDuplicates:$false` | Keeps repeats within pages and across pages, unless maintenance subsequently removes them. |
| `-DeduplicateFiles` plus `-DeduplicateWhen None` | Legacy mapping selects Start deduplication. |
| `-DeduplicateFiles` plus non-None `-DeduplicateWhen` | Explicit timing wins. |
| `-SortOutput:$true` plus `-SortWhen None` | Legacy output-only sorting at the end. |
| Previous combination plus `-DeduplicateFiles` | Also sorts source/output/blacklist files at the start; output is sorted again at the end. |
| `-SortOutput:$true` plus non-None `-SortWhen` | Explicit sorting phases win; those phases target source/output/blacklist files. |
| `-IgnoreMaintenanceLargeFileLimit` plus a nonzero maintenance limit | The ignore switch disables that size guard. |
| `-DelaySeconds 0` plus positive `-DelayJitterSeconds` | Inter-URL waits still include random jitter. |
| A small watchdog plus long HTTP/retry/second-fetch waits | The watchdog can interrupt/restart the URL before those configured durations finish. |
| `-Version`, `-Help` and `-InteractiveHelp` together | Version wins; without Version, Help wins over InteractiveHelp. |

### Accepted but inactive in the selected mode

| Option | When it has no useful effect |
| --- | --- |
| `-FollowScope`, `-FollowSubdomains`, `-MaxSubdomainDepth`, `-MaxFollowPages` | Crawling is disabled. |
| `-FollowPathScope SeedPath` | Crawling is disabled; emits a warning. |
| `-FollowSubdomains`, `-MaxSubdomainDepth` | Scope is SameHost or Any; MaxSubdomainDepth also needs FollowSubdomains true to allow extra subdomains. |
| `-ThrottleLimit` above 1 on PowerShell 7+ | One source URL without crawling; warns and uses sequential processing. |
| `-SecondFetchWait` | SecondFetch is false. |
| `-BlacklistScope` | No blacklist entries were loaded. |
| `-ExcludeMode` | No exclusion patterns were supplied. |
| `-RobotsUserAgent` | Robots enforcement is off; it still participates in the resume signature. |
| `-LogMode`, `-FailedUrlMode` | Their respective file paths are absent. |
| `-Files` | Command Run; warns and ignores this target list. |
| `-SortDirection` | No sorting operation is enabled. |
| `-DeduplicateWhen`/`-SortWhen` with standalone Deduplicate or Sort | The named command selects the operation directly; use Maintain to select operations through those flags. |
| HTTP, extraction and crawl settings | Standalone maintenance does not fetch or extract; shared early validations can still reject invalid arguments. |
| `-ConnectionLimit` | PowerShell 7 uses HttpClient connection management. |
| `-HighFailureRatePercent` | Crawling or a single non-crawl URL; the warning is implemented for non-crawl File jobs. |
| `-RetryFailedOnFinish` | No failures, a deadline stop, or no usable script/progress path for the extra pass. Missing prerequisites warn rather than manufacture recovery state. |

### Which settings must match for resume?

The signature is a configuration fingerprint, **not a checksum of every input file's contents**. Preserve the original source and blacklist files as well as their paths if you want a consistent continuation.

| Included in every run signature | Included additionally when crawling |
| --- | --- |
| SourceType; source value/path; absolute output path; effective include patterns and SearchMode; effective exclusion patterns and ExcludeMode; BlacklistScope and blacklist paths; SecondFetch; EnforceRobotsTxt and RobotsUserAgent; KeepDuplicates, NoDuplicates and KeepFragments; regex-stripping state and regex text. | Crawl-enabled state; unlimited-depth state; FollowDepth; FollowScope; FollowPathScope; FollowSubdomains; MaxSubdomainDepth; MaxFollowPages. |

For File mode, source paths are made absolute. Blacklist paths are made absolute, sorted and deduplicated. Effective search/exclusion pattern order can still affect the signature, so reuse the original command rather than rearranging equivalent filters.

Worker count, ordinary timing settings, watchdog duration, quiet mode, headers, proxy, default scheme and several operational limits are not part of this signature in 1.8.0. The code may therefore accept changes to them on resume, but acceptance is not a guarantee of identical request behaviour. In particular, changing headers or normalisation settings can change returned content or URLs.

`-ProgressFile` selects which journal to load; it is not itself a replacement for compatible inputs. Do not switch casually between `-FollowDepth -1` and `-FollowUntilExhausted` while resuming: the signature contains both the unlimited flag and the numeric depth representation.

### Zero-value meanings

| Parameter set to 0 | Meaning |
| --- | --- |
| FollowDepth | No crawling unless FollowUntilExhausted enables it. |
| MaxFollowPages | No crawl page cap. |
| MaxSubdomainDepth | No extra-subdomain depth cap when that policy is active. |
| StuckUrlTimeoutSeconds | Watchdog disabled. |
| MaxRunMinutes | No run scheduling deadline. |
| DelaySeconds, WaitSeconds, SecondFetchWait | No wait for that specific delay category. |
| DelayJitterSeconds | No random extra inter-URL delay. |
| MaintenanceLargeFileLimitMB, MaxPageContentMB | Corresponding size guard disabled. |
| RegexTimeoutSeconds | Infinite regex timeout; warns. |
| MaxUrlLength | URL-length guard disabled. |
| MaxRetryAfterSeconds | Ignore Retry-After and use ordinary retry-delay handling; not an unlimited server wait. |
| HighFailureRatePercent | High-failure warning disabled. |
| FileWriteRetryDelayMinMs/MaxMs, FileMoveRetryDelayMs | Zero delay for that bound/operation; minimum must still be no greater than maximum. |

RetryCount, TimeoutSeconds, ThrottleLimit, MaxRedirects, FileWriteRetryCount, FileMoveRetryCount and ConnectionLimit all require at least **1**. Zero is invalid for these options.


## Important limitations

AE-Find-WebLinks is not a browser.

It does not:

- execute JavaScript;
- click buttons;
- scroll pages;
- perform interactive website login flows;
- solve captchas;
- render dynamic pages;
- discover links created only after browser-side JavaScript execution.

It works best on links present in the raw HTTP response, including HTML, text, CSS, script text, JSON-like payloads, and embedded URL patterns.

For JavaScript-rendered websites, use a browser-based crawler instead, or provide AE-Find-WebLinks with URLs from already-rendered or exported pages.

Additional boundaries to keep in mind:

- The tool builds link lists; it does not download each file referenced by those links.
- URL extraction is heuristic and cannot discover every possible encoding or dynamically generated URL.
- Crawl discovery skips recognised static-asset extensions; matching asset links can still be saved.
- `SameDomain` is an approximation, not full Public Suffix List matching.
- Private/internal source and redirect URLs are blocked by built-in checks. DNS resolution still depends on the OS/.NET resolver, and the script does not claim to eliminate DNS-rebinding risks.
- `robots.txt` enforcement is opt-in, not enabled by default.
- Parallel execution can change output order; use sorting when order matters.
- Resume depends on compatible progress and retained output; it is not transactional recovery across every interruption point.

## Licence and feedback

AE-Find-WebLinks is released under [The Unlicense](https://github.com/mukkino/AE-Find-WebLinks/blob/main/LICENSE), with no warranty. It may be used, modified and distributed for personal or commercial purposes under that licence.

For bug reports and feature requests, visit the [project page](https://alterego.cc/wp/ae-find-weblinks/) or the [GitHub repository](https://github.com/mukkino/AE-Find-WebLinks).
