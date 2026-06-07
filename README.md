# AE-Find-WebLinks
Use this version if you want the original one-page extraction behaviour, or if you need controlled recursive crawling for archive discovery, download-list generation, or path-limited link discovery.

---

## Requirements

* Windows PowerShell 5.1 or PowerShell 7+.
* PowerShell 7+ is required only when using parallel processing with `-ThrottleLimit` greater than `1`.
* No external PowerShell modules required.
* No browser required.

Crawl mode is intentionally sequential in this version. If crawling is enabled, use `-ThrottleLimit 1`.

---

## Main capabilities

AE-Find-WebLinks can:

* Scan one URL.
* Scan many URLs from a text file.
* Extract links from raw HTTP responses.
* Extract URL tokens from less-clean source files, including copied text, logs, CSV-style lines, and HTML-like content.
* Match links using one wildcard pattern or multiple wildcard patterns.
* Use `Any` or `All` matching logic for include patterns.
* Exclude links using one or more wildcard patterns.
* Use `Any` or `All` matching logic for exclusion patterns.
* Write matching links to a plain text output file.
* Append to an existing output file or create a fresh output file.
* Avoid writing duplicate links already present in the output file.
* Optionally keep duplicate matches found within the same page.
* Preserve or ignore URL fragments during deduplication.
* Use one or more exact-URL blacklist files.
* Apply blacklists to input URLs, output links, or both.
* Resume interrupted non-crawl file-mode runs using a progress file.
* Detect changed run settings before resuming.
* Retry failed requests.
* Honour HTTP and meta-refresh redirect limits.
* Optionally fetch a page twice and keep the larger response.
* Use a custom User-Agent.
* Use an HTTP proxy.
* Log per-URL processing statistics to CSV.
* Save failed source URLs to a separate tab-separated file.
* Use independent append/new modes for output, CSV log, and failed URL files.
* Process URL lists sequentially or, outside crawl mode, in parallel.
* Deduplicate and sort files before or after a scraping run.
* Clean failed or stale maintenance temporary files created by deduplication and sorting.
* Run standalone maintenance commands without fetching URLs.
* Protect against dangerous file collisions.
* Warn when failure rates are high.
* Expose operational limits as command-line parameters instead of hardcoded values.
* Show built-in help with `-Help` or `-h`.
* Start a guided interactive command builder with `-InteractiveHelp` or `-Interactive`.
* When started without parameters, ask whether to show help, open the guided command builder, or exit.

---

## Crawling and link following

AE-Find-WebLinks can optionally follow links discovered on source pages.

The crawler has two separate behaviours:

1. **Discovery:** which links are allowed to be followed.
2. **Saving:** which links are written to the output file.

Crawl discovery intentionally ignores `SearchPattern`. This is important because intermediate index, category, navigation, or pagination pages may not match your search pattern, but they may lead to links that do.

`SearchPattern` controls only what is written to the output file.

For example, if you search for:

```powershell
"*news*story*"
```

the crawler may still follow pages that do not contain `news` or `story` in the URL, as long as those pages are allowed by the crawl scope. Only links matching `*news*story*` are saved.
