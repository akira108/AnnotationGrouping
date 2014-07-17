//
//  AGViewController.m
//  AnnotationGrouping
//
//  Created by Akira Iwaya on 2014/07/17.
//  Copyright (c) 2014年 akira108. All rights reserved.
//

// http://stackoverflow.com/questions/7132207/grouped-ungroup-mkannotation-depending-on-the-zoom-level-and-keep-it-fast
// http://stackoverflow.com/questions/20175605/marker-clustering-with-google-maps-sdk-for-ios/20271466#20271466

#import "AGViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "PointMapItem.h"

@interface AGViewController () <MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *allAnnotationMapView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@end

@implementation AGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.mapView.delegate = self;
    self.allAnnotationMapView.delegate = self;
    [self createRandomAnnotations];
    
}

- (void)createRandomAnnotations {
    const CGFloat baseLat = 35.681382;
    const CGFloat baseLng = 139.766084;
    
    for(int i=0;i<1000;i++) {
        CGFloat latDelta = rand()*0.125/RAND_MAX - 0.02;
        CGFloat lonDelta = rand()*0.130/RAND_MAX - 0.08;
        CLLocationCoordinate2D newCoord = {baseLat+latDelta, baseLng+lonDelta};
        PointMapItem *item = [[PointMapItem alloc] init];
        item.shouldBeMerged = YES;
        [item setCoordinate:newCoord];
        [self.allAnnotationMapView addAnnotation:item];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    
    static NSString* Identifier = @"PinAnnotationIdentifier";
    MKPinAnnotationView* pinView;
    pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:Identifier];
    
    if (pinView == nil) {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation
                                                  reuseIdentifier:Identifier];
        pinView.animatesDrop = YES;
        return pinView;
    }
    pinView.annotation = annotation;
    return pinView;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if(mapView == self.mapView) {
        [self updateVisibleAnnotations];
    }
}

- (void)updateVisibleAnnotations {
    static float marginFactor = 2.0f;
    static float bucketSize = 50.0f;
    MKMapRect visibleMapRect = [self.mapView visibleMapRect];
    MKMapRect adjustedVisibleMapRect = MKMapRectInset(visibleMapRect, -marginFactor * visibleMapRect.size.width, -marginFactor * visibleMapRect.size.height);
    
    CLLocationCoordinate2D leftCoordinate = [self.mapView convertPoint:CGPointZero toCoordinateFromView:self.view];
    CLLocationCoordinate2D rightCoordinate = [self.mapView convertPoint:CGPointMake(bucketSize, 0) toCoordinateFromView:self.view];
    double gridSize = MKMapPointForCoordinate(rightCoordinate).x - MKMapPointForCoordinate(leftCoordinate).x;
    MKMapRect gridMapRect = MKMapRectMake(0, 0, gridSize, gridSize);
    
    double startX = floor(MKMapRectGetMinX(adjustedVisibleMapRect) / gridSize) * gridSize;
    double startY = floor(MKMapRectGetMinY(adjustedVisibleMapRect) / gridSize) * gridSize;
    double endX = floor(MKMapRectGetMaxX(adjustedVisibleMapRect) / gridSize) * gridSize;
    double endY = floor(MKMapRectGetMaxY(adjustedVisibleMapRect) / gridSize) * gridSize;
    
    gridMapRect.origin.y = startY;
    while(MKMapRectGetMinY(gridMapRect) <= endY) {
        gridMapRect.origin.x = startX;
        while (MKMapRectGetMinX(gridMapRect) <= endX) {
            NSSet *allAnnotationsInBucket = [self.allAnnotationMapView annotationsInMapRect:gridMapRect];
            NSSet *visibleAnnotationsInBucket = [self.mapView annotationsInMapRect:gridMapRect];
            
            NSMutableSet *filteredAnnotationsInBucket = [[allAnnotationsInBucket objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                BOOL isPointMapItem = [obj isKindOfClass:[PointMapItem class]];
                BOOL shouldBeMerged = NO;
                if (isPointMapItem) {
                    PointMapItem *pointItem = (PointMapItem *)obj;
                    shouldBeMerged = pointItem.shouldBeMerged;
                }
                return shouldBeMerged;
            }] mutableCopy];
            NSSet *notMergedAnnotationsInBucket = [allAnnotationsInBucket objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                BOOL isPointMapItem = [obj isKindOfClass:[PointMapItem class]];
                BOOL shouldBeMerged = NO;
                if (isPointMapItem) {
                    PointMapItem *pointItem = (PointMapItem *)obj;
                    shouldBeMerged = pointItem.shouldBeMerged;
                }
                return isPointMapItem && !shouldBeMerged;
            }];
            for (PointMapItem *item in notMergedAnnotationsInBucket) {
                [self.mapView addAnnotation:item];
            }
            
            if(filteredAnnotationsInBucket.count > 0) {
                PointMapItem *annotationForGrid = (PointMapItem *)[self annotationInGrid:gridMapRect usingAnnotations:filteredAnnotationsInBucket];
                [filteredAnnotationsInBucket removeObject:annotationForGrid];
                annotationForGrid.containedAnnotations = [filteredAnnotationsInBucket allObjects];
                [self.mapView addAnnotation:annotationForGrid];
                //force reload of the image because it's not done if annotationForGrid is already present in the bucket!!
//                MKAnnotationView* annotationView = [self.mapView viewForAnnotation:annotationForGrid];
//                NSString *imageName = [AnnotationsViewUtils imageNameForItem:annotationForGrid selected:NO];
//                UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 2, 8, 8)];
//                [countLabel setFont:[UIFont fontWithName:POINT_FONT_NAME size:10]];
//                [countLabel setTextColor:[UIColor whiteColor]];
//                [annotationView addSubview:countLabel];
//                imageName = [AnnotationsViewUtils imageNameForItem:annotationForGrid selected:NO];
//                annotationView.image = [UIImage imageNamed:imageName];
                
                if (filteredAnnotationsInBucket.count > 0){
                    [self.mapView deselectAnnotation:annotationForGrid animated:NO];
                }
                for (PointMapItem *annotation in filteredAnnotationsInBucket) {
                    [self.mapView deselectAnnotation:annotation animated:NO];
                    annotation.clusterAnnotation = annotationForGrid;
                    annotation.containedAnnotations = nil;
                    if ([visibleAnnotationsInBucket containsObject:annotation]) {
                        CLLocationCoordinate2D actualCoordinate = annotation.coordinate;
                        [UIView animateWithDuration:0.3 animations:^{
                            annotation.coordinate = annotation.clusterAnnotation.coordinate;
                        } completion:^(BOOL finished) {
                            annotation.coordinate = actualCoordinate;
                            [self.mapView removeAnnotation:annotation];
                        }];
                    }
                }
            }
            gridMapRect.origin.x += gridSize;
        }
        gridMapRect.origin.y += gridSize;
    }
}

- (id<MKAnnotation>)annotationInGrid:(MKMapRect)gridMapRect usingAnnotations:(NSSet *)annotations {
    NSSet *visibleAnnotationsInBucket = [self.mapView annotationsInMapRect:gridMapRect];
    NSSet *annotationsForGridSet = [annotations objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        BOOL returnValue = ([visibleAnnotationsInBucket containsObject:obj]);
        if (returnValue) {
            *stop = YES;
        }
        return returnValue;
    }];
    
    if (annotationsForGridSet.count != 0) {
        return [annotationsForGridSet anyObject];
    }
    MKMapPoint centerMapPoint = MKMapPointMake(MKMapRectGetMinX(gridMapRect), MKMapRectGetMidY(gridMapRect));
    NSArray *sortedAnnotations = [[annotations allObjects] sortedArrayUsingComparator:^(id obj1, id obj2) {
        MKMapPoint mapPoint1 = MKMapPointForCoordinate(((id<MKAnnotation>)obj1).coordinate);
        MKMapPoint mapPoint2 = MKMapPointForCoordinate(((id<MKAnnotation>)obj2).coordinate);
        
        CLLocationDistance distance1 = MKMetersBetweenMapPoints(mapPoint1, centerMapPoint);
        CLLocationDistance distance2 = MKMetersBetweenMapPoints(mapPoint2, centerMapPoint);
        
        if (distance1 < distance2) {
            return NSOrderedAscending;
        }
        else if (distance1 > distance2) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    return [sortedAnnotations objectAtIndex:0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
