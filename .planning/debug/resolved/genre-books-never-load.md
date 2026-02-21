---
status: resolved
trigger: "Tapping genre card does not load books - stuck on loading, times out, goes back to genre screen"
created: 2026-02-21T00:00:00Z
updated: 2026-02-21T09:19:00Z
---

## Current Focus

hypothesis: Multiple compounding issues cause genre books to never load -- slow API compounded by missing trailing slash redirect, DiscoveryView preloading all 14 genres blocking the main actor, and @MainActor serialisation of all API calls
test: Verified via curl timing, code analysis, and API parameter testing
expecting: Confirmed all three root causes
next_action: Report diagnosis

## Symptoms

expected: Tapping a genre card should navigate to GenreBooksView and load books within a few seconds
actual: App shows "Loading genres..." for an extremely long time, then if the user taps a genre card, GenreBooksView shows "Loading books..." but times out or navigates back before books arrive
errors: No explicit error messages -- the API returns valid data, it just takes too long
reproduction: Tap Discover globe icon -> wait for genres -> tap any genre card -> observe loading spinner that never resolves
started: Since Discovery feature was implemented

## Eliminated

- hypothesis: CancellationError not caught properly
  evidence: CancellationError catch clauses were added in plan 06-03, already present in GutendexService.swift
  timestamp: 2026-02-21 (previous investigation)

- hypothesis: Invalid API endpoint or wrong base URL
  evidence: gutendex.com/books returns 301 redirect to /books/ which URLSession follows. API is reachable and returns valid JSON.
  timestamp: 2026-02-21

- hypothesis: Invalid topic parameter values
  evidence: Gutendex docs confirm `topic` is a valid parameter for bookshelf/subject search. curl with topic=fiction returns 30,454 books, topic=adventure returns 7,874 books.
  timestamp: 2026-02-21

- hypothesis: mime_type parameter is invalid
  evidence: Gutendex docs confirm `mime_type` is a valid prefix-matching filter. application/epub works and returns results.
  timestamp: 2026-02-21

## Evidence

- timestamp: 2026-02-21
  checked: GutendexService.swift baseURL value
  found: baseURL = "https://gutendex.com/books" (MISSING trailing slash)
  implication: Every API request gets a 301 redirect to /books/ before the actual query executes, adding latency to every request

- timestamp: 2026-02-21
  checked: curl timing for API without trailing slash
  found: 301 response in 0.14s, but following redirect the full round-trip takes 46-92 seconds depending on filters
  implication: The Gutendex API itself is extremely slow (46-92s per request). The redirect adds a small penalty but the core issue is API latency.

- timestamp: 2026-02-21
  checked: curl timing for various parameter combinations
  found: |
    - /books/?page=1 (no filters): ~20s
    - /books/?topic=fiction&page=1: ~46s
    - /books/?topic=fiction&languages=en&mime_type=application/epub&page=1: ~67-92s
  implication: Each additional filter parameter significantly increases API response time. The combination of topic + languages + mime_type makes requests extremely slow.

- timestamp: 2026-02-21
  checked: DiscoveryView.loadGenreCovers() implementation
  found: Fires API requests for ALL 14 genres in batches of 4, each calling gutendexService.fetchBooks(topic:page:). At ~60-90s per request, this means ~4 batches x ~60-90s = 4-6 MINUTES just to load the genre covers page.
  implication: The DiscoveryView is essentially DDoS-ing the Gutendex API with 14 parallel requests, and the user sees "Loading genres..." for minutes

- timestamp: 2026-02-21
  checked: GutendexService @MainActor annotation + DiscoveryView withTaskGroup usage
  found: GutendexService is @MainActor. DiscoveryView.loadGenreCovers() creates a withTaskGroup with child tasks that each call gutendexService.fetchBooks(). Since fetchBooks is @MainActor isolated, all child task calls must hop to the main actor. Within each batch of 4, the URLSession.shared.data(from:) calls CAN run concurrently (they await off the main actor), but the setup/teardown and state mutations (isLoading, error, cache) are serialized on main actor.
  implication: The @MainActor constraint means isLoading/error state is shared and potentially confusing across concurrent requests, but the network calls themselves do run concurrently within a batch.

- timestamp: 2026-02-21
  checked: GenreBooksView navigation path and .task modifier
  found: DiscoveryView uses NavigationLink(value: genre) with .navigationDestination(for: Genre.self). GenreBooksView has .task { await loadInitialBooks() }. loadInitialBooks() calls gutendexService.fetchBooks(topic: genre.topic, page: 1).
  implication: When user taps a genre, the GenreBooksView .task fires a 15th API request on a server already being hammered by the 14 genre cover requests from DiscoveryView. The GutendexService's isLoading flag is shared -- it's being set by the genre cover fetches.

- timestamp: 2026-02-21
  checked: GenreBooksView loadInitialBooks guard clause
  found: `guard books.isEmpty else { return }` -- if books were somehow populated, it won't refetch. But on first load, books IS empty so this isn't the problem.
  implication: Not a direct cause, but the guard is fine.

- timestamp: 2026-02-21
  checked: Genre.id uses UUID() in init -- fresh UUID every time Genre is constructed
  found: Genre.all is a static let array of Genre instances, each with UUID(). Genre conforms to Hashable by topic (stable). But Genre also conforms to Identifiable with id: UUID.
  implication: Since Genre.all is `static let`, the UUIDs are created once per app launch and remain stable. NavigationLink(value: genre) uses Hashable conformance (topic-based), so navigation should be stable. NOT a problem.

- timestamp: 2026-02-21
  checked: Whether DiscoveryView genre cover loading could cache results for GenreBooksView
  found: GutendexService has a cache keyed by "\(topic)-\(page)" with 5-minute TTL. If DiscoveryView finishes loading genre "fiction" page 1, GenreBooksView for fiction would get a cache hit.
  implication: IF DiscoveryView finishes loading before user taps a genre, the GenreBooksView would get instant results from cache. But DiscoveryView takes 4-6 minutes to finish ALL genres, and users tap a genre card as soon as it appears, long before the loading completes.

- timestamp: 2026-02-21
  checked: User report "goes back to the genre screen"
  found: This is likely the SwiftUI .task cancellation behavior. If the user gets impatient and taps back, OR if the DiscoveryView rerenders causing navigation state changes, the .task in GenreBooksView gets cancelled. The CancellationError catch returns nil, and loadInitialBooks leaves isInitialLoad=true (correct behavior for retry). But the "going back" is probably the user giving up, not automatic navigation popping.
  implication: The root issue is that the API takes so long that users abandon the view, which cancels the task.

## Resolution

root_cause: |
  THREE compounding issues cause genre books to never load:

  1. **CRITICAL: DiscoveryView preloads ALL 14 genres on appear** (DiscoveryView.swift:60-88)
     The loadGenreCovers() function fires API requests for all 14 genres in batches of 4 just to get cover thumbnails for the genre card collage. With each Gutendex API request taking 46-92 seconds, this creates a 4-6 minute loading wall before the user can even SEE genre cards. This is the primary bottleneck the user experiences as "stuck on loading genres."

  2. **SIGNIFICANT: Missing trailing slash on base URL** (GutendexService.swift:10)
     baseURL = "https://gutendex.com/books" causes a 301 redirect on every single request to "https://gutendex.com/books/". While URLSession follows this automatically, it adds an unnecessary round-trip to every request on an already-slow API.

  3. **SIGNIFICANT: Over-filtered API queries are extremely slow** (GutendexService.swift:31-36)
     The combination of topic + languages + mime_type filters makes each request take 60-90s. Without the mime_type filter, requests are ~46s. Without any topic filter, ~20s. The mime_type=application/epub filter is the heaviest contributor to slowness.

  The user flow failure is:
  - User taps Discover icon
  - DiscoveryView fires 14 API requests (4 at a time, ~60-90s each)
  - User sees "Loading genres..." for minutes
  - Eventually some genre cards appear (if they wait)
  - User taps a genre card
  - GenreBooksView fires ANOTHER 60-90s API request
  - User gives up and goes back (cancelling the task)
  - Result: "books never load"

fix: (not applied -- diagnosis only)
verification: (not applied -- diagnosis only)
files_changed: []
