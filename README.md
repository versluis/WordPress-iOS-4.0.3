# WordPress for iOS (tweaked)

This is a fork of the fantastic WordPress for iOS 4.0.3 with my own tweaks applied. 


### Images are uploaded in selected order

Originally all image uploads happened concurrently. This means that the quickest upload is inserted first, regardless of which order images were selected in. In this fork images upload one at a time and are inserted into the post in the order they were selected in. 

I had been working on this for a whlie with many interruptions, so long in fact that the project has now changed and the file in question is no longer called in the current version of WordPress - hence I can't offer this as an official pull request anymore. I'm explaining exactly what I did in this article: http://pinkstone.co.uk/how-to-add-ordered-image-uploads-in-wordpress-for-ios-4-0-3/


### Links are pre-populated from Pasteboard

When you insert a link into your post, the URL field is pre-populated with the last item that was copied to the iOS lipboard/pasteboard (via select - copy). Makes for less tapping.

When you do not insert text into the "link description" textfield, WordPress will also use the URL as text. If you'd like to change this behaviour, take a look at the EditPostViewController.m in a method called showLinkView. I've added the comment "overrides text if nothing is selected".

I've also added an option that prepopulates the "link description" field with a default text in the same method. You can change the text there, or comment the line out if you don't need this feature.


### Changed Bundle ID

I have changed the Bundle ID to org.wordpress.dev to allow peaceful coexistence with the "real" WordPress app on the same device. Don't forget to change your Team ID before you build this fork.


### The "real" WordPress for iOS Source Code

The current version of WordPress is developed here: https://github.com/wordpress-mobile/WordPress-iOS/

