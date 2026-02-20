
# Blaze Books

## The One Liner
An app that can helps you read ebooks in a tracked word mode and can also read the words aloud at the same pace.

## What it is
It is an IOS app, for iphone and ipad, which will use Rapid Serial Visual Presentation (RSVP) to display one word at a time to let you read the book at advanced speeds. Or display the page in general and let you follow the highlighted word. It will also have an option to turn on voice mode where the book is also read at you using Apple Voice technology. Users should be able to pull down classic books or upload their own books.

## The Problem
Lots of RSVP and epub reader apps exist, but none have a voiceover mode. The reading and listening at the same time is said to enhance retention and focus when reading. Other apps have audiobook features but these are community read, require donwloading, are often poor, and so an artifical voice could be better.

## The Solution
This app will be iOS only, and will display a library view where users can upload books, browse books to download, see their existing books and read books.
## Key Features

### Library
- Users will have a library mode to view existing books and mange them into 'shelves'
- Users can remove books, upload a book they own, or download from project guttenberg
- The library will track latest books opened and read displaying a last read section and a 'continue reading' option

### Reading Interface
- Books can be  read in either RSVP mode or page mode
- Optionally, a voiceover can with a voiceover that Apple can supply via iOS
- Users can change the word per minutes rate from a slider
- The voiceover will adjust speed to follow the word being displayed on the screen so it tracks perfectly
- There will be a table of contents dropdown so users can jump around easily.
- Users can choice from the variety of voices apple offers, and it will download any files required
- The app will remember the position of every book you are reading
- Chapter skip controls will be available

### Sync on iCloud
- The library and data of positions in books will sync across a users devices so they can use any device they wish and pickup where they left off

## How it works under the hood
- Written in Swift for iOS
- Uses part of the iOS **AVFoundation framework**, specifically `AVSpeechSynthesizer` for voices
- Tracking of user metadata should be  SQLite database (unless something better exists)

## What makes it different
- No audiobook download required
- No internet connection required once books are downloaded and voices are downloded (if required). It should work offline for the user if they have no internet.

## Target User
- Someone who owns epubs that they want to read like an audiobook without buying them from somewhere like Audible or iTunes
- Someone who wants to focus read with audio and RSVP
- Someone who wants to quickly get through content in an engaged way

