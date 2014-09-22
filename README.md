# Retailer

Retailer is a platform for web applications written in XSLT.

Essentially it is a kind of XML transforming web proxy, able to present a RESTful API as another API. 

The application class is [com.conaltuohy.retailer.RetailerServlet](https://github.com/Conal-Tuohy/Retailer/blob/master/src/com/conaltuohy/retailer/RetailerServlet.java)

## How does it work?
When Retailer receives an HTTP request, it creates an XML representation of the the request and passes it to an XSLT. The result of the XSLT is passed back to the client. During the process of each request, the XSLT may make its own HTTP requests for other resources, and process the results. In this way, an XSLT can statelessly represent an underlying API as a different API, for instance:

* converting an XML document into HTML, 
* exposing a custom API as a standard Atom feed, or OAI-PMH provider, 
* presenting a SPARQL store as Linked Data, 
* providing a JSON view of an XML-based web service
* performing HTTP content negotiation, etc.

## The sample applications
The code contains three sample XSLT apps:

* [trove.xsl](https://github.com/Conal-Tuohy/Retailer/blob/master/etc/trove.xsl), which presents the API of the National Library of Australia's newspaper archive as an OAI-PMH provider. 
* [papers-past.xsl](https://github.com/Conal-Tuohy/Retailer/blob/master/etc/papers-past.xsl), which presents the API of the National Library of New Zealand's newspaper archive as an OAI-PMH provider. 
* [identity.xsl](https://github.com/Conal-Tuohy/Retailer/blob/master/etc/identity.xsl), which simply echoes back any request it receives (useful as a reference for XSLT developers)

To run one of the sample apps, you will need to download the [retailer.war](https://github.com/Conal-Tuohy/Retailer/releases/tag/v2.0) file, deploy it into a Java Servlet container such as Apache Tomcat, and configure it by specifying one or more initialization parameters.

To select which of the XSLT apps to run, specify its name as the value of the "xslt" initialization parameter. See below for specific examples.

### Trove
To run the Trove OAI-PMH provider app, you will need to apply for a [Trove API Key](http://help.nla.gov.au/trove/building-with-trove/api) from the National Library of Australia, and configure your Servlet container to provide the key to the Retailer Servlet as an "init-parameter" named "trove-key". In Tomcat, you can do this by creating a `trove.xml` file in `/var/lib/tomcat7/conf/Catalina/localhost`:
```xml
<Context path="/trove" 
	docBase="/path/to/retailer.war"
	antiResourceLocking="false">
  <Parameter name="trove-key" value="your-key-here" override="false"/>
</Context>
```
This will launch the Trove OAI-PMH provider at the location `http://localhost:8080/trove/`

The Trove provider supports three metadata schemas: `oai_dc`, `trove` (a straightforward representation of the Trove API's native format) and `html` (likely to be the most useful).

### Papers Past
To run the Papers Past OAI-PMH provider app, you will need to apply for a [DigitalNZ API Key](http://www.digitalnz.org/api_keys) from the National Library of New Zealand, and configure your Servlet container to provide the key to the Retailer Servlet as an "init-parameter" named "digitalnz-key". In Tomcat, you can do this by creating a `papers-past.xml` file in `/var/lib/tomcat7/conf/Catalina/localhost`:
```xml
<Context path="/papers-past" 
	docBase="/path/to/retailer.war"
	antiResourceLocking="false">
  <Parameter name="digitalnz-key" value="your-key-here" override="false"/>
</Context>
```
This will launch the Papers Past OAI-PMH provider at the location `http://localhost:8080/papers-past/`

The Papers Past provider supports three metadata schemas: `oai_dc`, `digitalnz` (a straightforward representation of the DigitalNZ API's native format) and `html` (likely to be the most useful).

### Identity
The `identity.xsl` app is simply an "identity" stylesheet; a stylesheet which echoes whatever input it receives. 

You can use it to test Retailer, and to help develop your own XSLT web apps. As a stub, it could be the starting point for a functional stylesheet. In your XSLT, you can use the XPath `document` function to read data from other sources, and transform it.

In Tomcat, you can install it by creating an `identity.xml` file in `/var/lib/tomcat7/conf/Catalina/localhost`:
```xml
<Context path="/identity" 
	docBase="/path/to/retailer.war"
	antiResourceLocking="false">
  <Parameter name="some-example" value="whatever you like" override="false"/>
  <Parameter name="another-example" value="somethign else" override="false"/>
</Context>
```
This will launch the Identity app at the location `http://localhost:8080/identity/` - to test it, visit e.g. `http://localhost:8080/identity/foo/bar/baz?parameter-1=one&parameter-2=two`

### Harvesting newspaper articles

Both the OAI-PMH providers include a feature which allows for a harvester to harvest the a set of search results, by specifying a `set` of e.g. `search:foo` to harvest all newspaper articles containing the word "foo". Although the use of a `set` is optional in OAI-PMH, you are warned not to attempt to harvest from these providers without specifying a `set`, because the newspaper corpora are both extremely large (in the millions).

To harvest, you will need an OAI-PMH harvester application such as [jOAI](http://www.dlese.org/dds/services/joai_software.jsp), and specify the following harvest parameters:

Parameter Name      | Value
--------------------|--------------------------------
Repository base URL | `http://localhost:8080/trove/` or `http://localhost:8080/papers-past/`
SetSpec             | `search:ned kelly`
Metadata format     | `html`

For details, see the blog posts [How to download bulk newspaper articles from Trove](http://conaltuohy.com/blog/how-to-download-bulk-newspaper-articles-from-trove/) and [How to download bulk newspaper articles from Papers Past](http://conaltuohy.com/blog/how-to-download-bulk-newspaper-articles-from-papers-past/)

## How to build the program
To build Retailer, you will need Java and [Apache Ant](http://ant.apache.org/).  On Ubuntu Linux, you can install Ant like so:
```
sudo apt-get install ant
```
Then you can just run:
```
ant
```
The `retailer.war` file will be built in the `dist` folder, and can then be deployed to your Servlet container.

