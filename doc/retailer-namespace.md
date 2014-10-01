# Retailer XML namespace

This is the [namespace document](http://www.w3.org/TR/webarch/#namespace-document) for the XML namespace called [http://conaltuohy.com/ns/retailer](http://conaltuohy.com/ns/retailer), which is a vocabulary used by the [Retailer](https://github.com/Conal-Tuohy/Retailer/blob/master/README.md) platform to represent HTTP requests.

There is as yet no schema for Retailer documents, but the language is simple. 

## The vocabulary
The root element of a Retailer document is `<request>`, representing an HTTP request received by a Retailer server. There are four types of child elements, each with a `name` attribute and text content.

* `<value>`
* `<parameter>`
* `<header>`
* `<context-parameter>`

A `<value>` element represents a data item provided by the web server. The possible values of the `name` attribute are derived from the names of accessor methods of the HTTPServletRequest interface 
defined in the Java Servlet specification. Most of them are derived from the HTTP request itself (the request URI, and the components that make it up), but also include the address of the client
host, and the date the request was made, in UTC time.

A `<parameter>` element represents a request parameter, taken either from the request URI, or from a form-encoded request entity body. Note that multiple parameters with the same name and different value may appear.

A `<header>` element represents an HTTP request header.

A `<context-parameter>` element represents configuration data provided to Retailer by the Servlet container. This is typically used to provide local parameters (such as passwords) to Retailer.


# Examples

See these example documents in this namespace:

* [http://conaltuohy.com/identity/](http://conaltuohy.com/identity/)
* [http://conaltuohy.com/identity/?x=a&x=b](http://conaltuohy.com/identity/?x=a&x=b)
* [http://conaltuohy.com/identity/foo/bar/baz?parameter-1=one&parameter-2=two](http://conaltuohy.com/identity/foo/bar/baz?parameter-1=one&parameter-2=two)



