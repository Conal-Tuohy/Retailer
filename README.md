Retailer
========

Retailer is an XML transforming web proxy useful for presenting a RESTful API as another API.

When Retailer receives an HTTP request, it creates an XML representation of the the request and passes it to an XSLT. The result of the XSLT is passed back to the client. During the process of each request, the XSLT may make its own HTTP requests for other resources, and process the results. In this way, an XSLT can statelessly represent an underlying API as a different API, for instance converting a custom API into a standard Atom feed, or OAI-PMH provider.

The code contains a single XSLT transformation, [trove.xsl](https://github.com/Conal-Tuohy/Retailer/blob/master/src/com/conaltuohy/retailer/trove.xsl), which presents the API of the National Library of Australia's newspaper archive as an OAI-PMH provider.

The application class is com.conaltuohy.retailer.RetailerServlet

java -cp lib/* com.conaltuohy.retailer.Retailer key=my-trove-api-key

