//
//  RKActiveResourceXMLParser.m
//
//  Created by Adam Elliot on 11-05-20.
//  Copyright 2011 Two Toasters. All rights reserved.
//

#import "RKActiveResourceXMLParser.h"
#import <libxml2/libxml/parser.h>

@interface RKActiveResourceXMLParser (Private)
- (RKARXMLType)extractType:(xmlElement *)element;
- (id)parseNode:(xmlNode*)node;

- (NSDictionary*)parseXML:(NSString*)xml;
@end

@implementation RKActiveResourceXMLParser

+ (NSDictionary*)parse:(NSString*)xml {
	return [[[self new] autorelease] parseXML:xml];
}

- (NSString *)trimmedValueFromNode:(xmlNode*)node {
	if (node->type != XML_TEXT_NODE) return nil;

	xmlChar* str = xmlNodeGetContent(node);
	NSString* part = [NSString stringWithCString:(const char*)str encoding:NSUTF8StringEncoding];
	part = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([part length] > 0)
		return part;

	return nil;
}

- (NSString *)parseStringNode:(xmlNode*)node {
	return [self trimmedValueFromNode:node];
}

- (NSDecimalNumber *)parseDecimalNode:(xmlNode*)node {
	NSString *val = [self trimmedValueFromNode:node];
	if (!val) return nil;

	return [NSDecimalNumber decimalNumberWithString:val];
}

- (NSNumber *)parseIntegerNode:(xmlNode*)node {
	NSString *val = [self trimmedValueFromNode:node];
	if (!val) return nil;

	return [NSNumber numberWithInt:[val intValue]];
}

- (NSDate *)parseDateNode:(xmlNode*)node {
	NSString *val = [self trimmedValueFromNode:node];
	if (!val) return nil;

	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateFormat:@"yyyy-MM-dd"];
	[formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
	return [formatter dateFromString:val];
}

- (NSDate *)parseDateTimeNode:(xmlNode*)node {
	NSString *val = [self trimmedValueFromNode:node];
	if (!val) return nil;

	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	NSString *format = ([val hasSuffix:@"Z"]) ? @"yyyy-MM-dd'T'HH:mm:ss'Z'" : @"yyyy-MM-dd'T'HH:mm:ssz";
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateFormat:format];
	[formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
	
	NSDate	*dt = nil;
	NSError	*err = nil;
	[formatter getObjectValue:&dt forString:val range:nil error:&err];

	return dt;
}

- (NSNumber *)parseBooleanNode:(xmlNode*)node {
	NSString *val = [self trimmedValueFromNode:node];
	if (!val) return nil;

	return [NSNumber numberWithBool:
		[[val lowercaseString] isEqualToString:@"true"] ||
			[val isEqualToString:@"1"]];
}

- (NSArray *)parseArrayNode:(xmlNode*)node {
	NSMutableArray* ret = [NSMutableArray array];
	
	xmlNode* currentNode = NULL;
	for (currentNode = node; currentNode; currentNode = currentNode->next) {
		if (currentNode->type == XML_ELEMENT_NODE) {
			id val = [self parseNode:currentNode];
			if (val)
				[ret addObject:val];
		}
	}

	return ret;
}

- (NSDictionary *)parseDictionaryNode:(xmlNode*)node {
	NSMutableDictionary *ret = [NSMutableDictionary dictionary];
	NSString *nodeName;

	xmlNode* currentNode = NULL;
	for (currentNode = node->children; currentNode; currentNode = currentNode->next) {
		if (currentNode->type == XML_ELEMENT_NODE) {
			nodeName = [NSString stringWithCString:(char*)currentNode->name encoding:NSUTF8StringEncoding];

			id val = [self parseNode:currentNode];
			[ret setValue:val forKey:nodeName];
		}
	}

	nodeName = [NSString stringWithCString:(char*)node->name encoding:NSUTF8StringEncoding];
	return [NSDictionary dictionaryWithObject:ret forKey:nodeName];
}

- (RKARXMLType)extractType:(xmlElement *)element {
	xmlAttribute* currentAttribute = NULL;

	for (currentAttribute = (xmlAttribute*)element->attributes; currentAttribute; currentAttribute = (xmlAttribute*)currentAttribute->next) {
		NSString* name = [NSString stringWithCString:(char*)currentAttribute->name encoding:NSUTF8StringEncoding];
		if ([name caseInsensitiveCompare:@"type"] != NSOrderedSame) continue;
		
		NSString* val = [NSString stringWithCString:(char*)xmlNodeGetContent((xmlNode*)currentAttribute) encoding:NSUTF8StringEncoding];
		
		if ([val caseInsensitiveCompare:@"decimal"] == NSOrderedSame) {
			return RKARXMLTypeDecimal;
		} else if ([val caseInsensitiveCompare:@"integer"] == NSOrderedSame) {
			return RKARXMLTypeInteger;
		} else if ([val caseInsensitiveCompare:@"date"] == NSOrderedSame) {
			return RKARXMLTypeDate;
		} else if ([val caseInsensitiveCompare:@"datetime"] == NSOrderedSame) {
			return RKARXMLTypeDateTime;
		} else if ([val caseInsensitiveCompare:@"boolean"] == NSOrderedSame) {
			return RKARXMLTypeBoolean;
		} else if ([val caseInsensitiveCompare:@"array"] == NSOrderedSame) {
			return RKARXMLTypeArray;
		}
	}

	// If the first node is text it might just be whitespace, check the second
	// for element node. If there is only one node check to see if it's an element
	if (element->children && ((element->children->next && element->children->next->type == XML_ELEMENT_NODE) || 
														element->children->type == XML_ELEMENT_NODE))
		return RKARXMLTypeDictionary;

	return RKARXMLTypeString;
}

- (id)parseNode:(xmlNode*)node {
	if (!node->children) return nil;
	
	id val = nil;
	if (node->type == XML_ELEMENT_NODE) {
		xmlElement* element = (xmlElement*)node;
		RKARXMLType type = [self extractType:element];

		switch (type) {
			case RKARXMLTypeBoolean:
			case RKARXMLTypeDateTime:
			case RKARXMLTypeDate:
			case RKARXMLTypeInteger:
			case RKARXMLTypeDecimal:
			case RKARXMLTypeString:
				val = [self parseStringNode:node->children];
				break;
//			case RKARXMLTypeDecimal:
//				val = [self parseDecimalNode:node->children];
//				break;
//			case RKARXMLTypeInteger:
//				val = [self parseIntegerNode:node->children];
//				break;
//			case RKARXMLTypeDate:
//				val = [self parseDateNode:node->children];
//				break;
//			case RKARXMLTypeDateTime:
//				val = [self parseDateTimeNode:node->children];
//				break;
//			case RKARXMLTypeBoolean:
//				val = [self parseBooleanNode:node->children];
//				break;
			case RKARXMLTypeArray:
				val = [self parseArrayNode:node->children];
				break;
			case RKARXMLTypeDictionary:
				val = [self parseDictionaryNode:node];
				break;
		}
	}

	return val;
}

- (id)parseRootNode:(xmlNode *)rootNode {
	NSArray *nodes = [self parseArrayNode:rootNode];

	if ([nodes count] == 1) {
		return [nodes objectAtIndex:0];
	}

	if ([nodes count] == 0) {
		return @"";
	}

	return nodes;
}

- (NSDictionary*)parseXML:(NSString*)xml {
	xmlParserCtxtPtr ctxt; /* the parser context */
	xmlDocPtr doc; /* the resulting document tree */
	id result = nil;;
	
	/* create a parser context */
	ctxt = xmlNewParserCtxt();
	if (ctxt == NULL) {
		fprintf(stderr, "Failed to allocate parser context\n");
		return nil;
	}
	/* Parse the string. */
	const char* buffer = [xml cStringUsingEncoding:NSUTF8StringEncoding];
	doc = xmlParseMemory(buffer, strlen(buffer));
	
	/* check if parsing suceeded */
	if (doc == NULL) {
		fprintf(stderr, "Failed to parse\n");
	} else {
		/* check if validation suceeded */
		if (ctxt->valid == 0) {
			fprintf(stderr, "Failed to validate\n");
		}
		
		/* Parse Doc into Dict */
		result = [self parseRootNode:doc->xmlRootNode];
		
		/* free up the resulting document */
		xmlFreeDoc(doc);
	}
	/* free up the parser context */
	xmlFreeParserCtxt(ctxt);
	return result;
}

- (id)objectFromString:(NSString*)string {
	return [self parseXML:string];
}

- (NSString*)stringFromObject:(id)object {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end
