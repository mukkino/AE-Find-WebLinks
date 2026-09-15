# AE-Find-WebLinks 1.8.0

AE-Find-WebLinks is a PowerShell command-line tool for extracting, filtering, saving, and optionally crawling web links from either a single web page or a text file containing many source URLs.

It is built for link discovery, archive preparation, download-list building, deduplication, filtering, blacklist handling, long-running URL jobs, resumable crawling, stuck-URL watchdogs, failed-URL tracking, automatic retries, CSV logging, optional parallel processing, and maintenance of large text URL lists.

The script does **not** require a browser, Selenium, Playwright, ChromeDriver, or external PowerShell modules. It downloads the raw HTTP response and extracts links from common places such as HTML attributes, raw text, script blocks, JSON-like content, CSS `url(...)` references, `noscript` blocks, and embedded URL patterns.

It is a raw-response extraction and crawling tool, not a browser. It does **not** execute JavaScript or render web pages, and it does not download the files referenced by the extracted links.

---

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

Save the release script as `AE-Find-WebLinks.ps1`. From a PowerShell console in its folder:

```powershell
.\AE-Find-WebLinks.ps1 -Version
.\AE-Find-WebLinks.ps1 -Help
.\AE-Find-WebLinks.ps1 -InteractiveHelp
```

For a simple extraction into a new output file:

```powershell
.\AE-Find-WebLinks.ps1 -Source 'https://example.com/' -SearchPattern '*iana.org*' -OutputFile '.\links.txt' -Mode New
```

`-Mode New` creates or overwrites the output file. The default is `Append`. Use the built-in help for the full parameter reference and examples.

---

## Interruption and other important behaviour

**Ctrl+C does not guarantee exit code `130`.** The script returns `130` when its cancellation handler runs, but direct `powershell.exe -File` or `pwsh -File` execution can instead stop with exit `0` while work remains. Do not treat exit `0` alone as proof of completion after interruption.

For URL-file and crawl jobs, preserve the progress file, retain the same inputs/settings, and rerun with `-Resume`. Keep output and logs in `Append` mode. Reconcile intended sources with the source CSV and output; a missing progress file alone is not proof of completion. Recovery was observed at specific interruption points, not guaranteed at every possible write boundary.

`robots.txt` enforcement is **opt-in** through `-EnforceRobotsTxt`. Search and exclusion patterns control which links are written, not which in-scope pages are followed during crawling.

TLS certificate validation is enabled by default. `-SkipCertificateCheck` explicitly disables it for the request; leave validation enabled for normal use. The tool is not a browser and cannot guarantee access through JavaScript challenges, login flows, or anti-bot systems.
