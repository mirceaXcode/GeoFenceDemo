//
//  ViewController.m
//  GeoFenceDemo
//
//  Created by Mircea Popescu on 9/24/18.
//  Copyright © 2018 Mircea Popescu. All rights reserved.
//

#import "ViewController.h"
#import "MapKit/MapKit.h"

@interface ViewController () <CLLocationManagerDelegate, MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *uiSwitch;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *statusCheck;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *eventLabel;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) CLLocationManager *locationManager;

@property (nonatomic, assign) BOOL mapIsMoving;

@property (strong, nonatomic) MKPointAnnotation *currentAnno;
@property (strong, nonatomic) MKPointAnnotation *storeAnno;

@property (strong, nonatomic) CLCircularRegion *geoRegion;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Turn off the User Interface until permission is obtained
    self.uiSwitch.enabled = NO;
    self.statusCheck.enabled = NO;
    
    self.eventLabel.text = @"";
    self.statusLabel.text = @"";
    
    self.mapIsMoving = NO;
    
    // Set up the Location Manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.allowsBackgroundLocationUpdates = YES;
    self.locationManager.pausesLocationUpdatesAutomatically = YES;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = 3; //meters
    
    // Zoom the map very close
    CLLocationCoordinate2D noLocation = CLLocationCoordinate2DMake(0.0,0.0);
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(noLocation, 500, 500); //500 by 500
    MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:viewRegion];
    [self.mapView setRegion:adjustedRegion animated:YES];
    
    // Create an annotation for the user's location
    [self addCurrentAnnotation];
    
    // Setup a geoRegion object
    [self setUpGeoRegion];
    
    // Check if the device can do geofences
    if ([CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]] == YES){
        
        CLAuthorizationStatus currentStatus = [CLLocationManager authorizationStatus];
        if((currentStatus == kCLAuthorizationStatusAuthorizedWhenInUse) ||
           (currentStatus == kCLAuthorizationStatusAuthorizedAlways)){
            self.uiSwitch.enabled = YES;
        }
        else {
            // If not authorized, try and get it authorized
            [self.locationManager requestAlwaysAuthorization];
        }
        
        // Ask for notification permissions if the app is in the background
        UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
        UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
        
    } else{
        self.statusLabel.text = @"GeoRegions not supported";
    }
    
}

-(void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    CLAuthorizationStatus currentStatus = [CLLocationManager authorizationStatus];
    if((currentStatus == kCLAuthorizationStatusAuthorizedWhenInUse) ||
       (currentStatus == kCLAuthorizationStatusAuthorizedAlways)){
        self.uiSwitch.enabled = YES;
    }
}

-(void) mapView:(MKMapView *) mapView regionWillChangeAnimated:(BOOL)animated{
    self.mapIsMoving = YES;
}

-(void) mapView:(MKMapView *) mapView regionDidChangeAnimated:(BOOL)animated{
    self.mapIsMoving = NO;
}

-(void) setUpGeoRegion{
    // Create the Geographic region to be monitored
    self.geoRegion = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(30.390920,-97.747996) radius:10 identifier:@"MyRegionIdentifier"];
}

- (IBAction)switchTapped:(id)sender {
    
    if(self.uiSwitch.isOn){
        self.mapView.showsUserLocation = YES;
        [self.locationManager startUpdatingLocation];
        [self.locationManager startMonitoringForRegion:self.geoRegion];
        self.statusCheck.enabled = YES;
    }
    else {
        self.statusCheck.enabled = NO;
        [self.locationManager stopMonitoringForRegion:self.geoRegion];
        [self.locationManager stopUpdatingLocation];
        self.mapView.showsUserLocation = NO;
    }
}

- (void) addCurrentAnnotation {
    self.currentAnno = [[MKPointAnnotation alloc] init];
    self.currentAnno.coordinate = CLLocationCoordinate2DMake(0.0, 0.0);
    self.currentAnno.title = @"My Location";
}

-(void) centerMap:(MKPointAnnotation *)centerPoint{
    [self.mapView setCenterCoordinate:centerPoint.coordinate animated:YES];
}

#pragma mark - location call backs

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    self.currentAnno.coordinate = locations.lastObject.coordinate;
    if(self.mapIsMoving == NO){
        [self centerMap:self.currentAnno];
    }
}

- (IBAction)statusCheckTapped:(id)sender {
    [self.locationManager requestStateForRegion:self.geoRegion];
}

#pragma mark - geoFence call backs

-(void) locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region{
    if(state == CLRegionStateUnknown){
        self.statusLabel.text = @"Unknown";
    } else if (state == CLRegionStateInside){
        self.statusLabel.text = @"Inside";
    } else if (state == CLRegionStateOutside){
        self.statusLabel.text = @"Outside";
    } else {
        self.statusLabel.text = @"Mystery";
    }
}

-(void) locationManager:(CLLocationManager *)manager didEnterRegion:(nonnull CLRegion *)region{
    
    UILocalNotification *note = [[UILocalNotification alloc] init];
    note.fireDate = nil;
    note.repeatInterval = 0;
    note.alertTitle = @"GeoFence Alert!";
    note.alertBody = [NSString stringWithFormat:@"You entered the geofence"];
    [[UIApplication sharedApplication] scheduleLocalNotification:note];
    
    self.eventLabel.text = @"Entered";
    
}

-(void) locationManager:(CLLocationManager *)manager didExitRegion:(nonnull CLRegion *)region{

    UILocalNotification *note = [[UILocalNotification alloc] init];
    note.fireDate = nil;
    note.repeatInterval = 0;
    note.alertTitle = @"GeoFence Alert!";
    note.alertBody = [NSString stringWithFormat:@"You left the geofence"];
    [[UIApplication sharedApplication] scheduleLocalNotification:note];

    self.eventLabel.text = @"Exited";
}




@end
