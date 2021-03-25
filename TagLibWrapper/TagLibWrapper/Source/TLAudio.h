#import <Foundation/Foundation.h>

@interface TLAudio: NSObject
@property (readonly)  NSString *path;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *artist;
@property (nonatomic) NSString *album;
@property (nonatomic) NSString *comment;
@property (nonatomic) NSString *genre;
@property (nonatomic) NSNumber *year;
@property (nonatomic) NSNumber *track;
@property (nonatomic) NSData *frontCoverPicture;
@property (nonatomic) NSData *artistPicture;


- (instancetype)initWithFileAtPath:(NSString *)path;
- (BOOL)save;

@end
