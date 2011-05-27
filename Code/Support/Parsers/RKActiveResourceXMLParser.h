//
//  RKActiveResourceXMLParser.h
//
//  Created by Adam Elliot on 11-05-20.
//  Copyright 2011 Two Toasters. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKParser.h"

typedef enum {
	RKARXMLTypeString = 0,
	RKARXMLTypeDecimal,
	RKARXMLTypeInteger,
	RKARXMLTypeDate,
	RKARXMLTypeDateTime,
	RKARXMLTypeBoolean,
	RKARXMLTypeArray,
	RKARXMLTypeDictionary
} RKARXMLType;

@interface RKActiveResourceXMLParser : NSObject <RKParser> {
}

+ (NSDictionary*)parse:(NSString*)xml;

@end
