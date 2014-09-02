#import "WPMediaUploader.h"
#import "Media.h"

// Notifications
extern NSString *const MediaShouldInsertBelowNotification;

NSString *const WPMediaUploaderUploadOperation = @"upload_operation";

@interface WPMediaUploader() {
    NSMapTable *_mediaUploads;
    NSUInteger _numberOfImagesToUpload;
    NSUInteger _numberOfImagesProcessed;
}

@property int currentUpload;
@property (nonatomic, strong) NSArray *mediaToUpload;

@end

@implementation WPMediaUploader

- (id)init
{
    self = [super init];
    if (self) {
        _mediaUploads = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}

- (void)uploadMediaObjects:(NSArray *)mediaObjects
{
    if ([mediaObjects count] == 0)
        return;
    
    _numberOfImagesToUpload += [mediaObjects count];
    
    self.isUploadingMedia = YES;
    
    // CHANGE FOR ORDERED IMAGE UPLAODS
    
    // store reference to media array
    self.mediaToUpload = mediaObjects;
    
    // observer for next media
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(uploadNext) name:@"UploadTheNextMediaThing" object:nil];
    
    // upload first object and increment counter
    [self uploadMedia:mediaObjects.firstObject];
    self.currentUpload++;

}

- (void)uploadNext {
    
    // called via observer when current upload has finished
    NSLog(@"uploadNext notification received");
    
    // is another upload required?
    if (self.currentUpload < self.mediaToUpload.count) {
        
        Media *nextMedia = [self.mediaToUpload objectAtIndex:self.currentUpload];
        [self uploadMedia:nextMedia];
        self.currentUpload++;
    
    } else {
        [self cleanup];
    }
    
}

- (void)cleanup {
    
    // cleanup to avoid crashes
    
    // remove observer
    [[NSNotificationCenter defaultCenter]removeObserver:self name:@"UploadTheNextMediaThing" object:nil];
    
    // reset counter and media array
    self.currentUpload = nil;
    self.mediaToUpload = nil;
    
}

- (void)uploadMedia:(Media *)media
{
    [self uploadMedia:media withSuccess:^{
        if ([media isDeleted]) {
            DDLogWarn(@"Media uploader found deleted media while uploading (%@)", media);
            return;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:MediaShouldInsertBelowNotification object:media];
        [media save];
        NSLog(@"I've finished uploading image: %@", media.filename);
        
        // post notification that we're done uploading
        NSNotification *notification = [NSNotification notificationWithName:@"UploadTheNextMediaThing" object:self];
        [[NSNotificationCenter defaultCenter]postNotification:notification];
        
        
    } failure:^(NSError *error){
        if (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) {
            DDLogWarn(@"Media uploader failed with cancelled upload: %@", error.localizedDescription);
            return;
        }
        
        [WPError showAlertWithTitle:NSLocalizedString(@"Upload failed", nil) message:error.localizedDescription];
        
        // post notification that we're done uploading
        NSNotification *notification = [NSNotification notificationWithName:@"UploadTheNextMediaThing" object:self];
        [[NSNotificationCenter defaultCenter]postNotification:notification];
        
    }];

}

- (void)cancelAllUploads
{
    for (Media *media in _mediaUploads) {
        NSDictionary *uploadInformation = [_mediaUploads objectForKey:media];
        AFHTTPRequestOperation *operation = [uploadInformation objectForKey:WPMediaUploaderUploadOperation];
        [operation cancel];
    }
    [_mediaUploads removeAllObjects];
    self.isUploadingMedia = NO;
    [self cleanup];
}

- (void)uploadMedia:(Media *)media withSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    NSString *mimeType = (media.mediaType == MediaTypeVideo) ? @"video/mp4" : @"image/jpeg";
    NSDictionary *object = [NSDictionary dictionaryWithObjectsAndKeys:
                            mimeType, @"type",
                            media.filename, @"name",
                            [NSInputStream inputStreamWithFileAtPath:media.localURL], @"bits",
                            nil];
    NSArray *parameters = [media.blog getXMLRPCArgsWithExtra:object];

    media.remoteStatus = MediaRemoteStatusProcessing;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void) {
        // Create the request asynchronously
        // TODO: use streaming to avoid processing on memory
        NSMutableURLRequest *request = [media.blog.api requestWithMethod:@"metaWeblog.newMediaObject" parameters:parameters];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            void (^failureBlock)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
                if ([media isDeleted] || media.managedObjectContext == nil) {
                    return;
                }

                media.remoteStatus = MediaRemoteStatusFailed;
                [_mediaUploads removeObjectForKey:media];
                _numberOfImagesProcessed++;
                [self updateUploadProgress];
                if (failure) {
                    failure(error);
                }
            };
            AFHTTPRequestOperation *operation = [media.blog.api HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                if ([media isDeleted] || media.managedObjectContext == nil)
                    return;

                NSDictionary *response = (NSDictionary *)responseObject;

                if (![response isKindOfClass:[NSDictionary class]]) {
                    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"The server returned an empty response. This usually means you need to increase the memory limit for your site.", @"")}];
                    failureBlock(operation, error);
                    return;
                }
                if([response objectForKey:@"videopress_shortcode"] != nil)
                    media.shortcode = [response objectForKey:@"videopress_shortcode"];

                if([response objectForKey:@"url"] != nil)
                    media.remoteURL = [response objectForKey:@"url"];
                
                if ([response objectForKey:@"id"] != nil) {
                    media.mediaID = [[response objectForKey:@"id"] numericValue];
                }

                media.remoteStatus = MediaRemoteStatusSync;
                [_mediaUploads removeObjectForKey:media];
                _numberOfImagesProcessed++;
                [self updateUploadProgress];
                if (success) {
                    success();
                }
            } failure:failureBlock];
            [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    if ([media isDeleted] || media.managedObjectContext == nil)
                        return;
                    media.progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
                });
            }];
            
            // Upload might have been canceled while processing
            if (media.remoteStatus == MediaRemoteStatusProcessing) {
                media.remoteStatus = MediaRemoteStatusPushing;
                [media.blog.api enqueueHTTPRequestOperation:operation];
                NSMutableDictionary *uploadInformation = [[NSMutableDictionary alloc] initWithDictionary:@{WPMediaUploaderUploadOperation: operation}];
                [_mediaUploads setObject:uploadInformation forKey:media];
            }
        });
    });
}

- (void)updateUploadProgress
{
    if (self.uploadProgressBlock) {
        self.uploadProgressBlock(_numberOfImagesProcessed, _numberOfImagesToUpload);
    }
    
    if (_numberOfImagesProcessed == _numberOfImagesToUpload && self.uploadsCompletedBlock) {
        self.isUploadingMedia = NO;
        self.uploadsCompletedBlock();
    }
}

@end
