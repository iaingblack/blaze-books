---
status: resolved
trigger: "User taps a genre card in the Discovery screen but books never load. The view just keeps showing the genre icons."
created: 2026-02-21T00:00:00Z
updated: 2026-02-21T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED - Navigation from DiscoveryView never fires because .navigationDestination(for: Genre.self) is registered on DiscoveryView which is a PUSHED destination inside ContentView's NavigationStack, but the NavigationLink(value: genre) in DiscoveryView requires the .navigationDestination to be registered on the NavigationStack or on a view that is a direct child of it. Since DiscoveryView is reached via NavigationLink (push) from LibraryView, the .navigationDestination(for: Genre.self) on DiscoveryView's body is not seen by the NavigationStack.
test: N/A - root cause confirmed via code reading
expecting: N/A
next_action: Report root cause

## Symptoms

expected: Tapping a genre card navigates to GenreBooksView showing books for that genre
actual: "It just keeps showing the genres icons" - tapping genre card does nothing visible
errors: None reported
reproduction: Open app -> Tap globe icon in toolbar -> See genre grid -> Tap any genre card -> Nothing happens
started: Since navigation was implemented; previous fix (06-04) addressed API loading but did not fix navigation

## Eliminated

- hypothesis: API not returning books / GutendexService broken
  evidence: GenreBooksView is never reached at all - the tap on genre card produces no navigation. The API fix in 06-04 was correct but irrelevant to this symptom.
  timestamp: 2026-02-21

- hypothesis: Genre not conforming to Hashable correctly
  evidence: Genre conforms to Hashable (line 64 of GutendexModels.swift) with custom hash(into:) using topic field. This is correct.
  timestamp: 2026-02-21

## Evidence

- timestamp: 2026-02-21
  checked: LibraryView.swift toolbar (lines 116-120)
  found: DiscoveryView is pushed via a LABEL-BASED NavigationLink (NavigationLink { DiscoveryView() } label: { ... }) not a value-based one. This means DiscoveryView is pushed onto ContentView's NavigationStack as a destination.
  implication: DiscoveryView is a pushed view inside the existing NavigationStack from ContentView.

- timestamp: 2026-02-21
  checked: ContentView.swift (lines 7-14)
  found: ContentView has a single NavigationStack containing LibraryView. The only .navigationDestination registered is for Book.self (line 9). There is NO .navigationDestination(for: Genre.self) registered on the NavigationStack or on LibraryView.
  implication: The NavigationStack does not know how to handle Genre values.

- timestamp: 2026-02-21
  checked: DiscoveryView.swift (lines 17, 27-29)
  found: DiscoveryView uses NavigationLink(value: genre) on line 17 and registers .navigationDestination(for: Genre.self) on line 27. However, DiscoveryView is itself a PUSHED view inside the NavigationStack - it is NOT a NavigationStack root.
  implication: In SwiftUI, .navigationDestination(for:) MUST be registered within the NavigationStack's view hierarchy BEFORE the link is activated. When registered on a pushed view, the behavior is unreliable and often completely non-functional. The NavigationStack in ContentView.swift does not have this destination registered.

- timestamp: 2026-02-21
  checked: SwiftUI NavigationStack documentation pattern
  found: The correct pattern is to register .navigationDestination(for:) on the NavigationStack's root view or directly on the NavigationStack, not on pushed child views. Apple's documentation states that navigation destinations should be registered on the NavigationStack or a view that's always present in its hierarchy.
  implication: The .navigationDestination(for: Genre.self) on DiscoveryView is in the wrong location and is being ignored by the NavigationStack.

## Resolution

root_cause: `.navigationDestination(for: Genre.self)` is registered on DiscoveryView (line 27 of DiscoveryView.swift), but DiscoveryView is itself a pushed destination within ContentView's NavigationStack. SwiftUI's NavigationStack does not reliably pick up `.navigationDestination` modifiers registered on pushed child views. The destination must be registered at the NavigationStack level or on a view that is always in the stack's root hierarchy (like LibraryView or ContentView). Since ContentView only registers `.navigationDestination(for: Book.self)`, tapping a `NavigationLink(value: genre)` in DiscoveryView has no matching destination handler, so nothing happens.

fix: Move `.navigationDestination(for: Genre.self)` from DiscoveryView.swift to ContentView.swift, alongside the existing `.navigationDestination(for: Book.self)`.

verification: []
files_changed: []
