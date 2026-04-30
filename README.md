# Find-WebLinks **Version 1.5**

Find-WebLinks is a PowerShell command-line tool for extracting links from web pages or from large text files containing many URLs.

It is designed for long-running link discovery jobs where you need filtering, deduplication, blacklist handling, logging, failure tracking, resume support, and optional file maintenance without needing a browser, Selenium, Playwright, or external PowerShell modules.

The script downloads the raw HTTP response and extracts URLs from common places such as HTML attributes, raw text, script blocks, JSON-like content, CSS `url(...)` references, `noscript` sections, and related embedded link patterns. It does **not** execute JavaScript or render pages like a real browser.

---

## Main capabilities in version 1.5

Version 1.5 is a major expansion from the older 1.1 README. It adds safer long-run behaviour, better filtering, resume support, parallel processing, standalone maintenance commands, and command-line overrides for operational limits.

Key capabilities:

- Scan one URL or a file containing many URLs.
- Extract links from raw HTTP responses without a browser.
- Match links using one wildcard pattern or multiple wildcard patterns.
- Use `Any` or `All` logic for search patterns.
- Exclude links using one or more wildcard patterns.
- Use `Any` or `All` logic for exclusion patterns.
- Write matching links to an output text file.
- Append to or recreate the main output file.
- Skip duplicates already present in the output file.
- Optionally keep duplicates found within the same page.
- Use one or more blacklist files.
- Apply blacklist files to input URLs, extracted output links, or both.
- Resume interrupted file-mode runs using a progress file.
- Detect changed run settings before resuming.
- Retry failed requests.
- Honour HTTP/meta-refresh redirect limits.
- Optionally fetch each URL twice and keep the larger response.
- Log per-URL processing statistics to CSV.
- Save failed URLs to a separate tab-separated file.
- Use independent append/new modes for output, CSV log, and failed URL files.
- Run deduplication and sorting before or after scraping.
- Run standalone maintenance commands without downloading anything.
- Process URL lists in parallel with PowerShell 7+.
- Use a custom User-Agent.
- Use an HTTP proxy.
- Override page-size, regex, redirect, retry, file-write, and maintenance limits from the command line.
- Warn on high failure rates during large file-mode jobs.
- Refuse dangerous file collisions, such as output file matching source, log, blacklist, failed URL, or progress file.
- Avoid accidental huge in-memory maintenance operations unless explicitly allowed.

---

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+.
- PowerShell 7+ is required only for parallel mode with `-ThrottleLimit` greater than `1`.
- No external PowerShell modules required.
- No browser required.

---

## Basic usage

```powershell
.\Find-WebLinks.ps1 "PAGE_OR_FILE" "WHAT_TO_FIND" "OUTPUT_FILE" [Append|New] [Url|File]
```

Examples:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "bbc-links.txt" New Url
```

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched-links.txt" Append File
```

The `*` wildcard means “anything”. For example:

```text
*news*        matches links containing news
*download*    matches links containing download
*bbc*weather* matches links containing bbc, then weather later in the link
*             matches everything
```

---

## Source modes

Find-WebLinks has two source modes.

| SourceType | Meaning |
|---|---|
| `Url` | `Source` is a single web page URL. |
| `File` | `Source` is a text file containing URLs, one per line. |

Single URL:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "links.txt" New Url
```

Many URLs from a file:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*sport*" "links.txt" New File
```

In `File` mode, results are written after each page, so useful partial output is kept even during long jobs.

---

## Output modes

The main output file supports two modes:

| Mode | Meaning |
|---|---|
| `Append` | Add new results to the end of the existing file. This is the default. |
| `New` | Create or overwrite the output file before writing results. |

Example using `New`:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File
```

Example using `Append`:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File
```

---

## Multiple search patterns

Version 1.5 supports multiple include patterns through `-SearchPatterns`.

Match links containing `news`, `sport`, or `weather`:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk" "*news*" "out.txt" -SearchPatterns "*sport*","*weather*"
```

By default, `-SearchMode Any` is used. That means a link is accepted if it matches **any** search pattern.

Match links that contain both `news` and `2026`:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk" "*news*" "out.txt" -SearchPatterns "*2026*" -SearchMode All
```

You can also use `-SearchPatterns` without the positional `SearchPattern`:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk" -SearchPatterns "*news*","*sport*" -OutputFile "out.txt"
```

---

## Excluding unwanted links

Version 1.5 supports exclusion patterns.

Save links containing `download` or `game`, but exclude links containing `demo` or `trailer`:

```powershell
.\Find-WebLinks.ps1 "urls.txt" -SearchPatterns "*download*","*game*" -ExcludePatterns "*demo*","*trailer*" -OutputFile "matched.txt" Append File
```

Save links containing both `amiga` and `lha`, but exclude anything containing `beta`:

```powershell
.\Find-WebLinks.ps1 "urls.txt" -SearchPatterns "*amiga*","*lha*" -SearchMode All -ExcludePattern "*beta*" -OutputFile "matched.txt" Append File
```

Exclude only when **all** exclude patterns match the same link:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -ExcludePatterns "*demo*","*trial*" -ExcludeMode All
```

Exclusion statistics are included in the CSV log.

---

## Resume interrupted runs

File-mode runs can be resumed with `-Resume`.

When running in `File` mode, the script writes completed source URLs to a progress file. If the run is interrupted, rerun the same command with `-Resume` to skip URLs that were already processed.

Example first run:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*zip*" "matched-links.txt" Append File -LogCsv "run-log.csv" -FailedUrlFile "failed-urls.txt"
```

Resume the same run:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*zip*" "matched-links.txt" Append File -LogCsv "run-log.csv" -FailedUrlFile "failed-urls.txt" -Resume
```

By default, the progress file is:

```text
<OutputFile>.progress
```

For example:

```text
matched-links.txt.progress
```

You can set it manually:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*zip*" "matched-links.txt" Append File -ProgressFile "my-run.progress" -Resume
```

Important resume behaviour:

- `-Resume` only applies to `SourceType File`.
- If a progress file exists and you do **not** use `-Resume`, the script refuses to start. This avoids accidentally overwriting or mixing an interrupted run.
- `-Resume` forces `Mode`, `LogMode`, and `FailedUrlMode` to `Append` to prevent data loss.
- Failed URLs are also marked as processed. They are written to `-FailedUrlFile` if supplied.
- The progress file includes a run signature so the script can detect changed search, exclude, output, blacklist, duplicate, and related settings.

---

## Logging and failed URL tracking

### CSV log

Use `-LogCsv` to write per-URL processing statistics.

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File -LogCsv "run-log.csv"
```

The CSV log contains:

```csv
Timestamp,SourceUrl,Status,Extracted,Matched,Excluded,Blacklisted,Duplicates,Written,Error
```

The script automatically creates the CSV header for new or empty files. If an existing CSV has a different header, the script warns that columns may be misaligned.

### Failed URL file

Use `-FailedUrlFile` to save URLs that failed to load.

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File -FailedUrlFile "failed.txt"
```

The failed URL file is tab-separated and contains:

```text
SourceUrl    Error
```

### Independent file modes

The main output file, CSV log, and failed URL file can each use their own mode:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched.txt" Append File -LogCsv "run-log.csv" -LogMode New -FailedUrlFile "failed.txt" -FailedUrlMode New
```

| Option | Default | Meaning |
|---|---:|---|
| `Mode` | `Append` | Controls the main output file. |
| `LogMode` | `Append` | Controls the CSV log file. |
| `FailedUrlMode` | `Append` | Controls the failed URL file. |

---

## Blacklist support

Use `-BlacklistFile` to exclude exact URLs.

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "out.txt" Append File -BlacklistFile "blocked.txt"
```

A blacklist file contains one URL per line:

```text
https://example.com/unwanted-page
https://example.com/another-page
```

Blank lines are ignored. Lines starting with `#` are ignored.

Blacklist matching is exact after normalisation. A blacklist entry such as:

```text
https://facebook.com
```

will **not** automatically block:

```text
https://facebook.com/some/page
```

### Blacklist scope

Use `-BlacklistScope` to control where the blacklist applies.

| BlacklistScope | Meaning |
|---|---|
| `Input` | Skip matching source URLs before fetching them. |
| `Output` | Remove matching extracted links from the final output. |
| `Both` | Apply both behaviours. This is the default. |

Examples:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "out.txt" Append File -BlacklistFile "blocked.txt" -BlacklistScope Input
```

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "out.txt" Append File -BlacklistFile "blocked.txt" -BlacklistScope Output
```

Multiple blacklist files are supported:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "out.txt" Append File -BlacklistFile "ads.txt","tracking.txt"
```

---

## Duplicate handling

By default, the script avoids writing duplicate links already present in the output file or already written during the current run.

| Option | Default | Meaning |
|---|---:|---|
| `-NoDuplicates` | `$true` | Skip links already written or already present in the output file. |
| `-KeepDuplicates` | off | Keep repeated matches found within the same page. |
| `-KeepFragments` | off | Preserve URL fragments such as `#section` during deduplication. Useful for some single-page apps. |

Disable duplicate protection:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -NoDuplicates:$false
```

Keep repeated matches from the same page:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -KeepDuplicates
```

Preserve URL fragments:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*" "matched.txt" Append File -KeepFragments
```

---

## Retry, timeout, and fetch behaviour

Default network behaviour:

| Option | Default | Meaning |
|---|---:|---|
| `-RetryCount` | `3` | Number of retry attempts per URL. |
| `-WaitSeconds` | `30` | Seconds to wait between retries for the same URL. |
| `-TimeoutSeconds` | `120` | HTTP timeout per request attempt. |
| `-DelaySeconds` | `5` | Seconds to wait between different URLs in `File` mode. |
| `-SecondFetch` | `$true` | Fetch each URL twice and keep the larger response. |
| `-SecondFetchWait` | `5` | Seconds to wait before the second fetch. |
| `-MaxRedirects` | `10` | Maximum HTTP/meta-refresh redirects. |
| `-MaxRetryAfterSeconds` | `300` | Maximum server `Retry-After` wait honoured. `0` means ignore. |
| `-UserAgent` | Chrome-like UA | Custom User-Agent string. |
| `-Proxy` | none | HTTP proxy URL. |

Examples:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File -RetryCount 5 -WaitSeconds 60
```

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File -SecondFetch:$false
```

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File -UserAgent "MyLinkScanner/1.0"
```

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" Append File -Proxy "http://proxy:8080"
```

---

## Parallel processing

Use `-ThrottleLimit` to process multiple source URLs in parallel.

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -ThrottleLimit 8
```

Important:

- Parallel mode requires PowerShell 7 or later.
- `-ThrottleLimit` greater than `1` is only useful in `SourceType File` mode.
- Worker threads fetch and extract links. The parent process handles filtering, writing, logging, and progress centrally to reduce file-lock races.
- Default is `1`, which means sequential processing.

---

## File maintenance during a normal run

Version 1.5 can deduplicate and sort involved files before or after a scraping run.

| Option | Default | Meaning |
|---|---:|---|
| `-DeduplicateWhen` | `None` | Deduplicate involved files at `Start`, `End`, or `Both`. |
| `-SortWhen` | `None` | Sort involved files at `Start`, `End`, or `Both`. |
| `-SortDirection` | `Ascending` | Sort order for maintenance sorting. |
| `-DeduplicateFiles` | off | Legacy switch. Maps to start deduplication if `-DeduplicateWhen` is not set. |
| `-SortOutput` | `$false` | Legacy switch. Sorts output after the run, preserving older behaviour. |

Example:

```powershell
.\Find-WebLinks.ps1 ".\urls.txt" "*zip*" ".\matches.txt" Append File -DeduplicateWhen Start -SortWhen End
```

This can be useful when working with large input/output/blacklist files that may already contain repeated entries.

---

## Standalone maintenance commands

Use `-Command` for maintenance-only mode. No URLs are fetched.

Deduplicate one or more files:

```powershell
.\Find-WebLinks.ps1 -Command Deduplicate -Files .\a.txt,.\b.txt
```

Sort one or more files:

```powershell
.\Find-WebLinks.ps1 -Command Sort -Files .\a.txt,.\b.txt -SortDirection Descending
```

Deduplicate and/or sort using `Maintain`:

```powershell
.\Find-WebLinks.ps1 -Command Maintain -Files .\a.txt,.\b.txt -DeduplicateWhen Start -SortWhen End
```

In standalone maintenance mode, `Start`, `End`, and `Both` collapse to a single maintenance pass because there is no scraping phase between them.

---

## Large-file maintenance safety limit

By default, in-memory maintenance operations such as deduplication and sorting are protected by a 1 GB limit.

This avoids accidentally loading very large files into memory.

Default:

```text
-MaintenanceLargeFileLimitMB 1024
```

Disable the limit for a controlled run:

```powershell
.\Find-WebLinks.ps1 -Command Deduplicate -Files .\huge.txt -MaintenanceLargeFileLimitMB 0
```

Or explicitly ignore the limit:

```powershell
.\Find-WebLinks.ps1 -Command Deduplicate -Files .\huge.txt -IgnoreMaintenanceLargeFileLimit
```

Use this carefully. Sorting or deduplicating very large files can consume a lot of RAM.

---

## Operational limit overrides

Version 1.5 exposes operational limits as command-line options instead of leaving them hardcoded.

| Option | Default | Meaning |
|---|---:|---|
| `-MaintenanceLargeFileLimitMB` | `1024` | Maximum MB for in-memory dedup/sort. `0` means no limit. |
| `-IgnoreMaintenanceLargeFileLimit` | off | Allow dedup/sort above the maintenance size limit. |
| `-MaxPageContentMB` | `50` | Maximum page body size to parse. `0` means no limit. |
| `-RegexTimeoutSeconds` | `10` | Regex match timeout. `0` means no timeout. |
| `-MaxUrlLength` | `8192` | Maximum URL/key length before truncation. `0` means no limit. |
| `-MaxRedirects` | `10` | Maximum HTTP/meta-refresh redirects. |
| `-MaxRetryAfterSeconds` | `300` | Maximum server `Retry-After` wait honoured. `0` means ignore. |
| `-ConnectionLimit` | `100` | .NET HTTP connection limit. |
| `-FileWriteRetryCount` | `5` | Append retry attempts for output, log, failed, and progress files. |
| `-FileWriteRetryDelayMinMs` | `50` | Minimum delay between append retries. |
| `-FileWriteRetryDelayMaxMs` | `300` | Maximum delay between append retries. |
| `-FileMoveRetryCount` | `5` | Replace retry attempts after dedup/sort temporary file write. |
| `-FileMoveRetryDelayMs` | `300` | Delay between dedup/sort replace retries. |
| `-HighFailureRatePercent` | `50` | Warn when file-mode failures reach this percentage. `0` disables the warning. |
| `-AllowExtremeOperationalValues` | off | Allow values above typo guardrails. |

Example: allow larger pages:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -MaxPageContentMB 250
```

Example: disable regex timeout for a controlled local test:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -RegexTimeoutSeconds 0
```

Example: increase file-write retry behaviour:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -FileWriteRetryCount 10 -FileWriteRetryDelayMinMs 100 -FileWriteRetryDelayMaxMs 1000
```

---

## Typo guardrails for extreme values

Many numeric parameters accept very large values so advanced users can intentionally override limits. To prevent accidental mistakes, version 1.5 also applies normal safety guardrails.

For example, this is probably a typo:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -RetryCount 100000
```

By default, the script rejects values above normal guardrails and tells you to rerun with:

```powershell
-AllowExtremeOperationalValues
```

Example intentional extreme run:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -RetryCount 100000 -AllowExtremeOperationalValues
```

Normal guardrails include:

| Parameter | Normal guardrail |
|---|---:|
| `RetryCount` | `100` |
| `WaitSeconds` | `86400` |
| `TimeoutSeconds` | `86400` |
| `DelaySeconds` | `86400` |
| `SecondFetchWait` | `86400` |
| `ThrottleLimit` | `64` |
| `MaxPageContentMB` | `1024` |
| `RegexTimeoutSeconds` | `3600` |
| `MaxUrlLength` | `1048576` |
| `MaxRedirects` | `100` |
| `MaxRetryAfterSeconds` | `86400` |
| `FileWriteRetryCount` | `100` |
| `FileWriteRetryDelayMinMs` | `86400000` |
| `FileWriteRetryDelayMaxMs` | `86400000` |
| `FileMoveRetryCount` | `100` |
| `FileMoveRetryDelayMs` | `86400000` |
| `ConnectionLimit` | `10000` |

These are typo guardrails, not hard technical ceilings.

---

## File collision protection

The script refuses to run when important files would collide with each other.

It checks for dangerous combinations involving:

- Source file.
- Output file.
- CSV log file.
- Failed URL file.
- Progress file.
- Blacklist files.

Examples of refused combinations:

- Source file is the same as output file.
- Output file is the same as blacklist file.
- Log CSV is the same as output file.
- Failed URL file is the same as source file.
- Progress file is the same as output, source, log, failed URL, or blacklist file.

This is intentional. It prevents accidental data loss.

---

## Common examples

### Search one page and create a new output file

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*sport*" "bbc-links.txt" New Url
```

### Search one page and append to an existing file

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*politics*" "bbc-links.txt" Append Url
```

### Search many pages from a text file

Create `urls.txt`:

```text
https://www.bbc.co.uk/news
https://www.bbc.co.uk/sport
https://www.bbc.co.uk/weather
```

Run:

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched-links.txt" New File
```

### Search multiple patterns and exclude unwanted results

```powershell
.\Find-WebLinks.ps1 "urls.txt" -SearchPatterns "*download*","*game*" -ExcludePatterns "*demo*","*trailer*" -OutputFile "matched.txt" Append File
```

### Resume a long run

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -LogCsv "run-log.csv" -FailedUrlFile "failed.txt" -Resume
```

### Run with fresh logs but appended output

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*news*" "matched.txt" Append File -LogCsv "run-log.csv" -LogMode New -FailedUrlFile "failed.txt" -FailedUrlMode New
```

### Parallel run with PowerShell 7+

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*download*" "matched.txt" Append File -ThrottleLimit 8
```

### Deduplicate before scraping and sort at the end

```powershell
.\Find-WebLinks.ps1 "urls.txt" "*zip*" "matches.txt" Append File -DeduplicateWhen Start -SortWhen End
```

### Deduplicate a huge file and override the 1 GB safety limit

```powershell
.\Find-WebLinks.ps1 -Command Deduplicate -Files .\huge.txt -MaintenanceLargeFileLimitMB 0
```

---

## Full options reference

| Option | Default | Description |
|---|---:|---|
| `Source` | none | URL or file path to process. |
| `SearchPattern` | none | Main wildcard pattern. Optional if `-SearchPatterns` is used. |
| `-SearchPatterns` | none | One or more wildcard patterns. |
| `-SearchMode` | `Any` | `Any` = match any pattern. `All` = match every pattern. |
| `-ExcludePattern` | none | Main wildcard exclusion pattern. |
| `-ExcludePatterns` | none | One or more wildcard exclusion patterns. |
| `-ExcludeMode` | `Any` | `Any` = exclude if any exclusion pattern matches. `All` = exclude only if all match. |
| `OutputFile` / `-OutputFile` | none | File where matched links are saved. |
| `Mode` | `Append` | `Append` or `New` for the main output file. |
| `SourceType` | `Url` | `Url` or `File`. |
| `-RetryCount` | `3` | Number of retry attempts per URL. |
| `-WaitSeconds` | `30` | Seconds between retries. |
| `-TimeoutSeconds` | `120` | HTTP timeout per request. |
| `-DelaySeconds` | `5` | Delay between URLs in file mode. |
| `-SecondFetch` | `$true` | Fetch each URL twice and keep the larger response. |
| `-SecondFetchWait` | `5` | Seconds before the second fetch. |
| `-KeepDuplicates` | off | Keep repeated matches found within the same page. |
| `-NoDuplicates` | `$true` | Skip links already written or already in the output file. |
| `-BlacklistFile` | none | One or more exact-URL blacklist files. |
| `-BlacklistScope` | `Both` | Apply blacklist to `Input`, `Output`, or `Both`. |
| `-ThrottleLimit` | `1` | Number of URLs to process in parallel. Requires PowerShell 7+ when greater than `1`. |
| `-Resume` | off | Resume a previous file-mode run using the progress file. |
| `-ProgressFile` | `<OutputFile>.progress` | Progress file for resume mode. |
| `-DeduplicateFiles` | off | Legacy deduplication switch. |
| `-KeepFragments` | off | Preserve URL fragments during deduplication. |
| `-Proxy` | none | HTTP proxy URL. |
| `-SortOutput` | `$false` | Legacy end-of-run output sorting switch. |
| `-Command` | `Run` | `Run`, `Deduplicate`, `Sort`, or `Maintain`. |
| `-Files` | none | Files for standalone maintenance commands. Alias: `-MaintenanceFiles`. |
| `-SortDirection` | `Ascending` | `Ascending` or `Descending`. |
| `-DeduplicateWhen` | `None` | `None`, `Start`, `End`, or `Both`. |
| `-SortWhen` | `None` | `None`, `Start`, `End`, or `Both`. |
| `-UserAgent` | Chrome-like UA | Custom User-Agent header. |
| `-LogCsv` | none | CSV file for per-URL processing statistics. |
| `-FailedUrlFile` | none | Tab-separated file for failed URLs and errors. |
| `-LogMode` | `Append` | `Append` or `New` for the CSV log. |
| `-FailedUrlMode` | `Append` | `Append` or `New` for the failed URL file. |
| `-MaintenanceLargeFileLimitMB` | `1024` | Max MB for in-memory maintenance. `0` means no limit. |
| `-IgnoreMaintenanceLargeFileLimit` | off | Ignore the maintenance large-file safety limit. |
| `-MaxPageContentMB` | `50` | Maximum page body size to parse. `0` means no limit. |
| `-RegexTimeoutSeconds` | `10` | Regex timeout. `0` means no timeout. |
| `-MaxUrlLength` | `8192` | Maximum URL/key length before truncation. `0` means no limit. |
| `-MaxRedirects` | `10` | Maximum HTTP/meta-refresh redirects. |
| `-MaxRetryAfterSeconds` | `300` | Max server Retry-After wait honoured. `0` means ignore. |
| `-FileWriteRetryCount` | `5` | Retry count for appending output/log/progress lines. |
| `-FileWriteRetryDelayMinMs` | `50` | Minimum delay between append retries. |
| `-FileWriteRetryDelayMaxMs` | `300` | Maximum delay between append retries. |
| `-FileMoveRetryCount` | `5` | Retry count for replacing files after maintenance. |
| `-FileMoveRetryDelayMs` | `300` | Delay between file replace retries. |
| `-ConnectionLimit` | `100` | .NET HTTP connection limit. |
| `-AllowExtremeOperationalValues` | off | Allow values above normal typo guardrails. |
| `-HighFailureRatePercent` | `50` | Warn when file-mode failures reach this percent. `0` disables. |

---

## Output files

Depending on the options used, the script may create:

```text
matched-links.txt              Matched links
run-log.csv                    Per-URL processing log
failed.txt                     Failed source URLs and errors
matched-links.txt.progress     Resume progress file
```

You can open `.txt` files with a text editor and `.csv` files with Excel or similar tools.

---

## Troubleshooting

### PowerShell says scripts are disabled

Run this once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then run the script again.

### A progress file already exists

This usually means a previous file-mode run was interrupted.

Use one of these options:

```powershell
-Resume
```

or delete the progress file if you want to start fresh.

You can also specify a different progress file:

```powershell
-ProgressFile "another-run.progress"
```

### No links are found

Possible causes:

- The page does not contain matching links.
- The search pattern is too specific.
- The links are generated by JavaScript after the page loads.
- The website blocked the request.
- The page requires login or cookies.
- The links were excluded by `-ExcludePattern` or `-ExcludePatterns`.
- The links were removed by the blacklist.
- The links were skipped as duplicates.

Try a broader search:

```powershell
.\Find-WebLinks.ps1 "https://www.bbc.co.uk/news" "*" "all-links.txt" New Url -LogCsv "run-log.csv"
```

### The script finds fewer links than the browser

That is expected on modern sites that rely on JavaScript. Find-WebLinks does not execute JavaScript, click buttons, scroll pages, accept cookie banners, or wait for React, Vue, Angular, or other client-side frameworks to build the page.

### Maintenance skipped a huge file

By default, maintenance operations such as deduplication and sorting are protected by a 1 GB safety limit.

To override it:

```powershell
-MaintenanceLargeFileLimitMB 0
```

or:

```powershell
-IgnoreMaintenanceLargeFileLimit
```

### Parallel mode fails

Parallel mode requires PowerShell 7+.

Check your version:

```powershell
$PSVersionTable.PSVersion
```

If you are on Windows PowerShell 5.1, use the default sequential mode or install PowerShell 7+.

---

## Limitations

Find-WebLinks is a best-effort raw-response link extraction tool.

It does **not**:

- Execute JavaScript.
- Render pages.
- Use a real browser engine.
- Click buttons.
- Accept cookie banners.
- Log into websites.
- Scroll pages.
- Wait for client-side frameworks to populate links.
- Bypass access controls.

If a link only appears after browser-side JavaScript runs, this script may not see it.

---

## Responsible use

Use this tool responsibly.

Respect website terms of service, robots.txt guidance where applicable, rate limits, copyright restrictions, and access controls. Do not use it to overload websites or collect data you are not allowed to access.

---

## License

This project is released under The Unlicense / public domain terms, as stated in the script header.
