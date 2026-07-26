//
//  WifiZoneViewController.h
//  Overland
//
//  Created by Aaron Parecki on 3/2/19.
//  Copyright © 2019 Aaron Parecki. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GLWifiZone;

// Presented modally in a code-built UINavigationController, since the storyboard
// has none. Both screens here are code, not storyboard scenes.
@interface WifiZoneListViewController : UITableViewController
@end

// Add or edit a single zone. Pass nil and NSNotFound to create a new one.
@interface WifiZoneEditorViewController : UITableViewController

- (instancetype)initWithZone:(GLWifiZone *)zone atIndex:(NSUInteger)index;

@end
