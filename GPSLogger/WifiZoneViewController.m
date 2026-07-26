//
//  WifiZoneViewController.m
//  Overland
//
//  Created by Aaron Parecki on 3/2/19.
//  Copyright © 2019 Aaron Parecki. All rights reserved.
//

#import "WifiZoneViewController.h"
#import "GLManager.h"

// 0 inherits the global setting, 1 means no minimum, matching the discard
// filter's > 1 test. Runs past the global control's 2 minute cap on purpose.
static const int kWifiZoneMinTimeValues[] = {0, 1, 5, 10, 30, 60, 120, 300, 600, 1800};
static const NSUInteger kWifiZoneMinTimeCount = sizeof(kWifiZoneMinTimeValues) / sizeof(int);

static NSString *WifiZoneMinTimeLabel(int seconds) {
    switch(seconds) {
        case 0:    return @"Same as global setting";
        case 1:    return @"No minimum";
        case 60:   return @"1 minute";
        case 120:  return @"2 minutes";
        case 300:  return @"5 minutes";
        case 600:  return @"10 minutes";
        case 1800: return @"30 minutes";
        default:   return [NSString stringWithFormat:@"%d seconds", seconds];
    }
}

static NSString *WifiZoneMinTimeShortLabel(int seconds) {
    if(seconds <= 0) {
        return @"global";
    }
    if(seconds < 60) {
        return [NSString stringWithFormat:@"%ds", seconds];
    }
    return [NSString stringWithFormat:@"%dm", seconds / 60];
}


#pragma mark - List

@interface WifiZoneListViewController ()

@property (strong, nonatomic) NSArray<GLWifiZone *> *zones;
@property (strong, nonatomic) NSString *currentSSID;

@end

@implementation WifiZoneListViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Wifi Zones";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addZoneWasTapped)];
    // Covers the tab bar, so Done is the only way out.
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneWasTapped)];
}

// The editor writes through GLManager and pops, so this re-read is the whole
// handoff, as in every other settings screen here.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.zones = [GLManager sharedManager].wifiZones;
    self.currentSSID = [GLManager currentWifiHotSpotName];
    [self.tableView reloadData];

    // SSID read is async, so reload once it lands to mark the current network.
    __weak WifiZoneListViewController *weakSelf = self;
    [[GLManager sharedManager] refreshCurrentWifiSSIDWithCompletion:^(NSString *ssid) {
        if([ssid isEqualToString:weakSelf.currentSSID]) {
            return;
        }
        weakSelf.currentSSID = ssid;
        [weakSelf.tableView reloadData];
    }];
}

- (void)doneWasTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)addZoneWasTapped {
    WifiZoneEditorViewController *editor = [[WifiZoneEditorViewController alloc] initWithZone:nil atIndex:NSNotFound];
    [self.navigationController pushViewController:editor animated:YES];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Placeholder row for the empty state: keeps the footer visible, needs no layout.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(1, (NSInteger)self.zones.count);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Whenever you're connected to one of these networks, your reported location is replaced with the coordinates you set here. A per-zone minimum time between points can further reduce how much is logged while you're there. Trip settings always take precedence.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // registerClass: forces StyleDefault, whose detailTextLabel is nil.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zone"];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"zone"];
    }

    if(self.zones.count == 0) {
        cell.textLabel.text = @"No wifi zones yet. Tap + to add one.";
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    GLWifiZone *zone = self.zones[indexPath.row];
    BOOL isCurrent = [GLWifiZone ssid:zone.ssid matchesSSID:self.currentSSID];

    // Dot on the connected network: quickest on-device check that matching works.
    cell.textLabel.text = isCurrent ? [NSString stringWithFormat:@"● %@", zone.ssid] : zone.ssid;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.5f, %.5f · min time: %@",
                                 zone.latitude, zone.longitude,
                                 WifiZoneMinTimeShortLabel(zone.minTimeBetweenPoints)];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.zones.count > 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if(editingStyle != UITableViewCellEditingStyleDelete || self.zones.count == 0) {
        return;
    }

    [[GLManager sharedManager] deleteWifiZoneAtIndex:indexPath.row];
    self.zones = [GLManager sharedManager].wifiZones;
    // Not deleteRowsAtIndexPaths: deleting the last zone leaves the row count at
    // 1 as the placeholder appears, which throws.
    [tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(self.zones.count == 0) {
        return;
    }

    WifiZoneEditorViewController *editor = [[WifiZoneEditorViewController alloc] initWithZone:self.zones[indexPath.row]
                                                                                     atIndex:indexPath.row];
    [self.navigationController pushViewController:editor animated:YES];
}

@end


#pragma mark - Editor

@interface WifiZoneEditorViewController () <UITextFieldDelegate>

@property (strong, nonatomic) UITextField *ssidField;
@property (strong, nonatomic) UITextField *latitudeField;
@property (strong, nonatomic) UITextField *longitudeField;

@end

@implementation WifiZoneEditorViewController {
    NSUInteger _index;      // NSNotFound for a new zone
    NSString *_ssidText;
    NSString *_latitudeText;
    NSString *_longitudeText;
    int _minTime;
}

- (instancetype)initWithZone:(GLWifiZone *)zone atIndex:(NSUInteger)index {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if(self) {
        _index = index;
        if(zone) {
            _ssidText = zone.ssid;
            _latitudeText = [NSString stringWithFormat:@"%.5f", zone.latitude];
            _longitudeText = [NSString stringWithFormat:@"%.5f", zone.longitude];
            _minTime = zone.minTimeBetweenPoints;
        } else {
            // Same prefill as the old single-zone screen.
            _ssidText = [GLManager currentWifiHotSpotName];
            CLLocation *last = [GLManager sharedManager].lastLocation;
            if(last) {
                _latitudeText = [NSString stringWithFormat:@"%.5f", last.coordinate.latitude];
                _longitudeText = [NSString stringWithFormat:@"%.5f", last.coordinate.longitude];
            }
            _minTime = 0;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = (_index == NSNotFound) ? @"New Wifi Zone" : @"Edit Wifi Zone";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save"
                                                                             style:UIBarButtonItemStyleProminent
                                                                            target:self
                                                                            action:@selector(saveWasTapped)];

    // Built once and held: rebuilding in cellForRow would drop the first
    // responder and anything typed.
    self.ssidField = [self fieldWithText:_ssidText keyboard:UIKeyboardTypeDefault placeholder:@"Network name"];
    // Not decimalPad: no minus key, so southern/western coords are untypeable.
    self.latitudeField = [self fieldWithText:_latitudeText keyboard:UIKeyboardTypeNumbersAndPunctuation placeholder:@"0.00000"];
    self.longitudeField = [self fieldWithText:_longitudeText keyboard:UIKeyboardTypeNumbersAndPunctuation placeholder:@"0.00000"];

    if(_index == NSNotFound) {
        // Prefill above used a possibly-unread cache. Never overwrite typing.
        __weak WifiZoneEditorViewController *weakSelf = self;
        [[GLManager sharedManager] refreshCurrentWifiSSIDWithCompletion:^(NSString *ssid) {
            if(ssid.length > 0 && weakSelf.ssidField.text.length == 0) {
                weakSelf.ssidField.text = ssid;
            }
        }];
    }
}

- (UITextField *)fieldWithText:(NSString *)text keyboard:(UIKeyboardType)keyboard placeholder:(NSString *)placeholder {
    // Accessory views size from their frame, so no constraints needed.
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
    field.text = text;
    field.placeholder = placeholder;
    field.keyboardType = keyboard;
    field.textAlignment = NSTextAlignmentRight;
    field.borderStyle = UITextBorderStyleNone;
    field.adjustsFontSizeToFitWidth = YES;
    field.minimumFontSize = 12;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.returnKeyType = UIReturnKeyDone;
    field.delegate = self;
    return field;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? 3 : (NSInteger)kWifiZoneMinTimeCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return (section == 0) ? @"Zone" : @"Minimum time between points";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if(section == 0) {
        return @"While connected to this network, your location is reported as these coordinates instead of the GPS position.";
    }
    return @"Overrides the global minimum time between points while you're connected to this network. Ignored while a trip is in progress.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        switch(indexPath.row) {
            case 0:
                cell.textLabel.text = @"Wifi name";
                cell.accessoryView = self.ssidField;
                break;
            case 1:
                cell.textLabel.text = @"Latitude";
                cell.accessoryView = self.latitudeField;
                break;
            default:
                cell.textLabel.text = @"Longitude";
                cell.accessoryView = self.longitudeField;
                break;
        }
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"minTime"];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"minTime"];
    }
    int seconds = kWifiZoneMinTimeValues[indexPath.row];
    cell.textLabel.text = WifiZoneMinTimeLabel(seconds);
    cell.accessoryType = (seconds == _minTime) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if(indexPath.section == 0) {
        // So tapping the label side focuses the field.
        [[self fieldForRow:indexPath.row] becomeFirstResponder];
        return;
    }

    _minTime = kWifiZoneMinTimeValues[indexPath.row];
    [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

- (UITextField *)fieldForRow:(NSInteger)row {
    switch(row) {
        case 0:  return self.ssidField;
        case 1:  return self.latitudeField;
        default: return self.longitudeField;
    }
}

#pragma mark - Saving

- (void)saveWasTapped {
    [self.view endEditing:YES];

    NSString *ssid = [self.ssidField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(ssid.length == 0) {
        [self rejectWithMessage:@"Enter a wifi network name."];
        return;
    }

    NSArray<GLWifiZone *> *existing = [GLManager sharedManager].wifiZones;
    for(NSUInteger i = 0; i < existing.count; i++) {
        if(i == _index) {
            continue;
        }
        GLWifiZone *other = existing[i];
        if([GLWifiZone ssid:other.ssid matchesSSID:ssid]) {
            [self rejectWithMessage:[NSString stringWithFormat:@"A zone for \"%@\" already exists.", other.ssid]];
            return;
        }
    }

    NSNumber *latitude = [self numberFromString:self.latitudeField.text];
    if(latitude == nil) {
        [self rejectWithMessage:@"Latitude must be a number."];
        return;
    }
    NSNumber *longitude = [self numberFromString:self.longitudeField.text];
    if(longitude == nil) {
        [self rejectWithMessage:@"Longitude must be a number."];
        return;
    }
    if([latitude doubleValue] < -90.0 || [latitude doubleValue] > 90.0) {
        [self rejectWithMessage:@"Latitude must be between -90 and 90."];
        return;
    }
    if([longitude doubleValue] < -180.0 || [longitude doubleValue] > 180.0) {
        [self rejectWithMessage:@"Longitude must be between -180 and 180."];
        return;
    }

    GLWifiZone *zone = [[GLWifiZone alloc] initWithSSID:ssid
                                              latitude:[latitude doubleValue]
                                             longitude:[longitude doubleValue]
                                  minTimeBetweenPoints:_minTime];
    if(![zone isValid]) {
        [self rejectWithMessage:@"Those coordinates aren't valid."];
        return;
    }

    [[GLManager sharedManager] saveWifiZone:zone atIndex:_index];
    [self.navigationController popViewControllerAnimated:YES];
}

// Not doubleValue: 0 for junk, period-only, so "48,13" would store as 48.0.
// Coords have no grouping separators, so normalize to "." and require isAtEnd.
- (NSNumber *)numberFromString:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(trimmed.length == 0) {
        return nil;
    }

    NSString *normalized = [trimmed stringByReplacingOccurrencesOfString:@"," withString:@"."];
    NSScanner *scanner = [NSScanner scannerWithString:normalized];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double value = 0;
    if(![scanner scanDouble:&value] || !scanner.isAtEnd) {
        return nil;
    }
    return [NSNumber numberWithDouble:value];
}

- (void)rejectWithMessage:(NSString *)message {
    NSLog(@"[WifiZone] rejected save: %@", message);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Can't save this zone"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
