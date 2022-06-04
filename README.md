# Discussions for Freshworks Interviewers

Hi there. This project should be able to build and run on an iPhone target running iOS 14.0 or later.

All codes my own, except for the content in `UIImage-Ext.swift`. The script copied from the internet is for displaying animated GIF images with UIImage. I figured this isn't something you'd be interested in see implemented on my own.

I did receive this assignment last-minute so I allocated 5 hours on Saturday for it. I'm glad it worked out.

Below are some discussions on some of the decisions I made and on notes for possible improvements/optimizations.

## Using User Defaults as on-disk storage

I debated using Core Data vs User Defaults. I went with the latter because it's easier to implement, and there's no plan to scale it up yet for sake of the assignment.

User Defaults is likely OK since we are storing dozens (or up to hundreds) of favourited GIFs. Core Data or another choice of structured storage should be considered if we are supporting 10,000x of items being favourited.

Finally, I used `synchronize()` upon session discard to force a save to the disk. This shouldn't be necessary in production. I'm using it to show interviewers that the favourited GIFs are indeed saved to disk, to save us from some confusion.

## Local caching and storage

Caching is done in RAM with `GIFImageCache` class (a subclass of NSCache). It's a singleton instance.

Some may despise the use of singleton but for sake of the assignment, singleton should do just fine. Plus, this singleton design is RAM-only, and there is no nasty storage migration when we do decide to build a better caching mechanism. It's likely not creating much technical debt.

You will see higher RAM usage because of caching. Cache eviction is handled by the NSCache mechanism and I didn't bother implementing my own. During testing, I can see that eviction happens when the app enters the background. There's definitely room for improvement other than OS default behaviour.

Storage is done with FileManager, and is located in the temporary folder. For sake of the assignment this should be OK, as the OS doesn't purge temporary folders as often.

The attempt to download photo to disk is initiated when the user favourites a GIF. There's no deletion when the user un-favourite a GIF, but there can be.

## Using thumbnails

Using thumbnails is another way to optimize for performance. Currently I'm using original images for both display and for caching/storage. Reasons for decision:

1. Thumbnails from GIPHY APIs are usually not much smaller, and sometimes are identical files. The effect on optimization would not be noticeable.
2. Performance is fine, with power to spare for my 8-year-old iPhone 6s.
3. I figured it wouldn't be of interest to interviewers watching me implement thumbnail use.

## Miscellaneous

- There should be a message when API requests fail, or when the user has 0 favourited GIFs and seeing an empty page. The specifications didn't ask for placeholder/error messages, so I did not implement those.

- The specifications didn't say what should come out of tapping a GIF, so I implemented my own:

    1. For GIFs that are still downloading, an alert tells the user to be patient for the GIF to finish loading
    2. For GIFs that are downloaded (to cache or to disk), a share sheet (UIActivityController) is presented with options to save it to album.

- Performance should be better if we use mp4 files for display, in place of GIF UIImage objects.
