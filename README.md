Retailer
========

Retailer is an XML transforming web proxy useful for presenting a RESTful API as another API.

When Retailer receives an HTTP request, it creates an XML representation of the the request and passes it to an XSLT. The result of the XSLT is passed back to the client. During the process of each request, the XSLT may make its own HTTP requests for other resources, and process the results. In this way, an XSLT can statelessly represent an underlying API as a different API, for instance:

* converting an XML document into HTML, 
* exposing a custom API as a standard Atom feed, or OAI-PMH provider, 
* presenting a SPARQL store as Linked Data, 
* performing content negotiation, etc.

The application class is [com.conaltuohy.retailer.RetailerServlet](https://github.com/Conal-Tuohy/Retailer/blob/master/src/com/conaltuohy/retailer/RetailerServlet.java)

The code contains a sample XSLT transformation, [retailer.xsl](https://github.com/Conal-Tuohy/Retailer/blob/master/etc/retailer.xsl), which presents the API of the National Library of Australia's newspaper archive as an OAI-PMH provider. To run the sample XSLT application, you will need to apply for a [Trove API Key](http://help.nla.gov.au/trove/building-with-trove/api) from the National Library of Australia, and configure your Servlet container to provide the key to the Retailer Servlet as an "init-parameter" named "key". The OAI-PMH provider implemented in the XSLT includes a feature which allows for a harvester to harvest the result of a search, by specifying a setSpec of "search:foo" to harvest all newspaper articles containing the word "foo". It's not recommended to attempt to harvest without using a setSpec, because the Trove corpus is very large and the service is slow; a complete harvest would likely take months to complete, if it did at all.

You can also test out Retailer by renaming the [identity.xsl](https://github.com/Conal-Tuohy/Retailer/blob/master/etc/identity.xsl) file to "retailer.xsl", and accessing the Retailer Servlet from your browser. The "identity.xsl" file simply copies the input document unchanged, so what you will see in your browser is the XML representation which Retailer made from your HTTP request and passed to the XSLT.

To build Retailer, you will need Java and [Apache Ant](http://ant.apache.org/).  On Ubuntu Linux, you can install Ant like so:
```
sudo apt-get install ant
```
Then you can just run:
```
ant
```
The `retailer.war` file will be built in the `dist` folder, and can then be deployed to your Servlet container.

