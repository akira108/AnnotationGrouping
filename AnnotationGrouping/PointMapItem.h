//
//  PointMapItem.h
//  AnnotationGrouping
//
//  Created by Akira Iwaya on 2014/07/17.
//  Copyright (c) 2014年 akira108. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface PointMapItem : MKPointAnnotation
@property(nonatomic, strong)NSArray *containedAnnotations;
@property(nonatomic, assign)BOOL shouldBeMerged;
@property(nonatomic, strong)PointMapItem *      clusterAnnotation;
@end
