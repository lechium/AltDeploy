//
//  ALTApplication.m
//  AltSign
//
//  Created by Riley Testut on 6/24/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTApplication.h"
#import "ALTProvisioningProfile.h"

#include "ldid.hpp"

@interface ALTApplication ()

@property (nonatomic, copy, nullable, readonly) NSString *iconName;

@end

@implementation ALTApplication
@synthesize entitlements = _entitlements;
@synthesize provisioningProfile = _provisioningProfile;

- (instancetype)initWithFileURL:(NSURL *)fileURL
{
    self = [super init];
    if (self)
    {
        NSBundle *bundle = [NSBundle bundleWithURL:fileURL];
        if (bundle == nil)
        {
            return nil;
        }
        
        // Load info dictionary directly from disk, since NSBundle caches values
        // that might not reflect the updated values on disk (such as bundle identifier).
        NSURL *infoPlistURL = [bundle.bundleURL URLByAppendingPathComponent:@"Info.plist"];
        NSDictionary *infoDictionary = [NSDictionary dictionaryWithContentsOfURL:infoPlistURL];
        if (infoDictionary == nil)
        {
            return nil;
        }
        
        NSString *name = infoDictionary[@"CFBundleDisplayName"] ?: infoDictionary[(NSString *)kCFBundleNameKey];
        NSString *bundleIdentifier = infoDictionary[(NSString *)kCFBundleIdentifierKey];
                
        if (name == nil || bundleIdentifier == nil)
        {
            return nil;
        }
        
        NSString *platform = infoDictionary[@"DTPlatformName"] ?: @"ios";
        NSString *version = infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
        NSString *minimumVersionString = infoDictionary[@"MinimumOSVersion"] ?: @"1.0";
        
        NSArray *versionComponents = [minimumVersionString componentsSeparatedByString:@"."];
        
        NSInteger majorVersion = [versionComponents.firstObject integerValue];
        NSInteger minorVersion = (versionComponents.count > 1) ? [versionComponents[1] integerValue] : 0;
        NSInteger patchVersion = (versionComponents.count > 2) ? [versionComponents[2] integerValue] : 0;
        
        NSOperatingSystemVersion minimumVersion;
        minimumVersion.majorVersion = majorVersion;
        minimumVersion.minorVersion = minorVersion;
        minimumVersion.patchVersion = patchVersion;
        
        NSDictionary *icons = infoDictionary[@"CFBundleIcons"];
        id primaryIcon = icons[@"CFBundlePrimaryIcon"];
        NSString *iconName = nil;
        if ([primaryIcon respondsToSelector:@selector(allKeys)]){
            NSArray *iconFiles = primaryIcon[@"CFBundleIconFiles"];
            if (iconFiles == nil) {
                iconFiles = infoDictionary[@"CFBundleIconFiles"];
            }
            iconName = [iconFiles lastObject];
            if (iconName == nil) {
                iconName = infoDictionary[@"CFBundleIconFile"];
            }
        } else {
            iconName = primaryIcon;
        }
        _fileURL = [fileURL copy];
        _name = [name copy];
        _bundleIdentifier = [bundleIdentifier copy];
        _version = [version copy];
        _minimumiOSVersion = minimumVersion;
        _iconName = [iconName copy];
        _platform = [platform copy];
    }
    
    return self;
}

#if TARGET_OS_IPHONE
- (UIImage *)icon
{
    NSBundle *bundle = [NSBundle bundleWithURL:self.fileURL];
    if (bundle == nil)
    {
        return nil;
    }
    
    NSString *iconName = self.iconName;
    if (iconName == nil)
    {
        return nil;
    }
    
    UIImage *icon = [UIImage imageNamed:iconName inBundle:bundle compatibleWithTraitCollection:nil];
    return icon;
}
#endif

- (NSDictionary<ALTEntitlement,id> *)entitlements
{
    if (_entitlements == nil)
    {
        NSDictionary<NSString *, id> *appEntitlements = @{};
        
        std::string rawEntitlements = ldid::Entitlements(self.fileURL.fileSystemRepresentation);
        if (rawEntitlements.size() != 0)
        {
            NSData *entitlementsData = [NSData dataWithBytes:rawEntitlements.c_str() length:rawEntitlements.size()];
            
            NSError *error = nil;
            NSDictionary *entitlements = [NSPropertyListSerialization propertyListWithData:entitlementsData options:0 format:nil error:&error];
            
            if (entitlements != nil)
            {
                appEntitlements = entitlements;
            }
            else
            {
                NSLog(@"Error parsing entitlements: %@", error);
            }
        }
        
        _entitlements = appEntitlements;
    }
    
    return _entitlements;
}

- (ALTProvisioningProfile *)provisioningProfile
{
    if (_provisioningProfile == nil)
    {
        NSURL *provisioningProfileURL = [self.fileURL URLByAppendingPathComponent:@"embedded.mobileprovision"];
        _provisioningProfile = [[ALTProvisioningProfile alloc] initWithURL:provisioningProfileURL];
    }
    
    return _provisioningProfile;
}

@end
