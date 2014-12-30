# WordPress for iOS (tweaked)

This is a fork of the fantastic WordPress for iOS 4.0.3 with my own tweaks applied. 


### Images are uploaded in selected order

Originally all image uploads happened concurrently. This meant that the quickest upload was inserted first, regardless of which order images were selected in. In this fork images upload one at a time and are inserted into the post in the order they were selected in.

I had been working on this for so long (with many interruptions) that the WordPress project has now changed and the file in question is no longer called - hence I can't offer this as an official pull request anymore. I'm explaining exactly what I did in this article: http://pinkstone.co.uk/how-to-add-ordered-image-uploads-in-wordpress-for-ios-4-0-3/


### Image HTML is separated by new lines

When inserting multiple images, all code blocks are inserted together. This looks like one huge block of code, making it very difficult to see where one images starts and another ends. I've added two new line breaks to make this easier to see. I've also removed one of the two BR tags that is inserted for additional media.

This can be tweaked in EditPostViewController.m in a method called insertMediaBelow (prefix is what you want to change).


### Links are pre-populated from UIPasteboard

When inserting a link into your post, the URL field is now pre-populated with the last item that was copied to the iOS clipboard (via select - copy). Makes for less tapping when you've just grabbed a link from Safari.

I've also added an option that prepopulates the "link description" field with a default text in the same method. You can change the text EditPostViewController.m in a method called showLinkView (_linkHelperAlertView.firstTextFieldValue), or comment the line out if you don't need this feature.


### Changed Bundle ID

I have changed the Bundle ID to org.wordpress.dev to allow peaceful coexistence with the "real" WordPress app on the same device. The display name has been updated to "WP Dev" so you can tell which version this is.

Don't forget to change your Team ID before building this fork.


### The "real" WordPress for iOS Source Code

The current version of WordPress is developed here: https://github.com/wordpress-mobile/WordPress-iOS/

