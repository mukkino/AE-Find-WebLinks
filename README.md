# AE-Find-WebLinks

AE-Find-WebLinks is a PowerShell command-line tool for extracting, filtering, saving, and optionally crawling web links from either a single web page or a text file containing many source URLs.

It is built for link discovery, archive preparation, download-list building, deduplication, filtering, blacklist handling, long-running URL jobs, resumable crawling, stuck-URL watchdogs, failed-URL tracking, automatic retries, CSV logging, optional parallel processing, and maintenance of large text URL lists.

The script does **not** require a browser, Selenium, Playwright, ChromeDriver, or external PowerShell modules. It downloads the raw HTTP response and extracts links from common places such as HTML attributes, raw text, script blocks, JSON-like content, CSS `url(...)` references, `noscript` blocks, and embedded URL patterns.

It is a raw-response extraction and crawling tool, not a browser. It does **not** execute JavaScript or render web pages.

---

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+.
- PowerShell 7+ is required only when using parallel processing with `-ThrottleLimit` greater than `1`.
- No external PowerShell modules required.
- No browser required.

Crawl mode is intentionally sequential in this version. If crawling is enabled, use `-ThrottleLimit 1`.

---

## Main capabilities

AE-Find-WebLinks can:

- Scan one URL.
- Scan many URLs from a text file.
- Extract links from raw HTTP responses.
- Extract URL tokens from less-clean source files, including copied text, logs, CSV-style lines, and HTML-like content.
- Match links using one wildcard pattern or multiple wildcard patterns.
- Use `Any` or `All` matching logic for include patterns.
- Exclude links using one or more wildcard patterns.
- Use `Any` or `All` matching logic for exclusion patterns.
- Strip unwanted dynamic parts of a URL via Regex before evaluation, deduplication, or output.
- Safely pause, interrupt, and resume both standard URL list runs and multi-depth site crawls.
- Automatically monitor and bypass hanging requests using a configurable stuck URL watchdog.
- Automatically perform a secondary retry pass on failed URLs at the end of a run.
- Write matching links to a plain text output file.
