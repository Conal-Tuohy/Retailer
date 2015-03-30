package com.conaltuohy.retailer;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URLEncoder;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.Date;
import java.util.TimeZone;
import java.util.Map;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Result;
import javax.xml.transform.Source;
import javax.xml.transform.Templates;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.Transformer;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.sax.SAXSource;
import javax.xml.transform.sax.SAXTransformerFactory;
import javax.xml.transform.sax.TransformerHandler;
import javax.xml.transform.stream.StreamResult; 
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.xml.sax.InputSource;

/**
 * Servlet implementation class RetailerServlet
 * The RetailerServlet is a fairly generic XSLT host, designed to be usable
 * for presenting XML data sources, such as XML databases, directories of XML files,
 * RSS feeds, SPARQL stores, etc.
 * Retailer was originally used (and still contains some cruft from) for the purpose of
 * providing an OAI-PMH service based on the National Library of Australia's Trove, 
 * which offers a custom XML-based search API. 
 */
public class RetailerServlet extends HttpServlet {
	private static final long serialVersionUID = 1L;
	
	private static final String RETAILER_NS = "http://conaltuohy.com/ns/retailer/";
	
	private final static SAXTransformerFactory transformerFactory = (SAXTransformerFactory) TransformerFactory.newInstance();
	private final static DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
       
    /**
     * @see HttpServlet#HttpServlet()
     */
    public RetailerServlet() {
        super();
    }
    
	/** Respond to an HTTP request using an XSLT transform.
	* • Load the XSLT transform - if this fails then the service() call fails
	* • Create an XML document representing the HTTP request
	* • Transform the document using the XSLT transform, returning the 
	* result to the HTTP client - if this fails, then retry, then give up.
	 * @see javax.servlet.http.HttpServlet#service(javax.servlet.http.HttpServletRequest, javax.servlet.http.HttpServletResponse)
	 */
	@Override
	public void service(HttpServletRequest req, HttpServletResponse resp)
			throws ServletException, IOException {
		
		// Because the XSLT can only use the GET method (via XPath document() function),
		// it can't really support PUT or DELETE, which are supposed to make persistent changes.
		// Only the GET and POST methods are supported.
		if ( ! ( "GET".equals(req.getMethod()) || "POST".equals(req.getMethod())) ) {
			throw new ServletException("Method not supported");
		}
		
		// Create a stream to send response XML to the HTTP client
		OutputStream os = resp.getOutputStream();
		Result result = new StreamResult(os);
		
		// TODO repeat until successful or too many retries
		// NB a ListRecords or ListIdentifiers request which is retried has the opportunity to
		// return an empty list to the harvester, without making a risky call to the upstream
		// server, and this trick might help to avoid the downstream harvester's
		// request timing out, while still enabling the harvester to continue the list sequence.
		
		// load and compile an XSLT Transform
		// The XSLT to use is specified by an initialization parameter
		String xslt = getServletContext().getInitParameter("xslt");
		if (xslt == null) {
			xslt = "identity.xsl";
		};
		xslt = "/WEB-INF/" + xslt;
		InputStream is = getServletContext().getResourceAsStream(xslt);
		InputSource inputSource = new InputSource(is);
		Source transformSource = new SAXSource(inputSource);
		// compile XSLT transform
		TransformerHandler transformerHandler = null;
		Transformer transformer = null;
		try {
			Templates xsltTemplates = transformerFactory.newTemplates(transformSource);
			transformerHandler = transformerFactory.newTransformerHandler(xsltTemplates);
			transformer = transformerHandler.getTransformer();
			resp.setContentType(
				transformer.getOutputProperties()
					.getProperty(OutputKeys.MEDIA_TYPE)
			);	
		} catch (TransformerConfigurationException xsltNotLoaded) {
			fail(xsltNotLoaded, "Error in XSLT transform");
		};

		// Create a document describing the HTTP request,
		// from request parameters, headers, etc.
		// to be the input document for the XSLT transform.
		Document requestXML = null;
		try {
			requestXML = factory.newDocumentBuilder().newDocument();
		} catch (ParserConfigurationException documentCreationFailed) {
			fail(documentCreationFailed, "Error creating DOM Document");
		}
		
		// Populate the XML document from the HTTP request data
		try {
			Element retailerElement = requestXML.createElementNS(RETAILER_NS, "request");
			requestXML.appendChild(retailerElement);
			
			// the current date and time is a useful value for the XSLT to know
			addElement(retailerElement, "value", "date", getCurrentDate());
			
			// miscellaneous properties of the HTTP request
			addElement(retailerElement, "value", "method", req.getMethod());
			addElement(retailerElement, "value", "request-url", req.getRequestURL().toString());
			addElement(retailerElement, "value", "request-uri", req.getRequestURI());
			addElement(retailerElement, "value", "query-string", req.getQueryString());
			addElement(retailerElement, "value", "context-path", req.getContextPath());
			addElement(retailerElement, "value", "servlet-path", req.getServletPath());
			addElement(retailerElement, "value", "path-info", req.getPathInfo());
			addElement(retailerElement, "value", "scheme", req.getScheme());
			addElement(retailerElement, "value", "server-name", req.getServerName());
			addElement(retailerElement, "value", "server-port", Integer.toString(req.getServerPort()));
			addElement(retailerElement, "value", "remote-addr", req.getRemoteAddr());
			
			// the form parameters, either from URI parameters or POST message body
			for (String name : Collections.list(req.getParameterNames())) {
				String[] values = req.getParameterValues(name);
				for (String value: values) {
					addElement(retailerElement, "parameter", name, value);
				}
			}
			
			// the HTTP request headers
			for (String name : Collections.list(req.getHeaderNames())) {
				addElement(retailerElement, "header", name, req.getHeader(name));
			}
			
			// The Servlet initialization parameters
			for (String name : Collections.list(getServletConfig().getInitParameterNames())) {
				addElement(retailerElement, "init-parameter", name, getServletConfig().getInitParameter(name));
			}
			
			// The web application's initialization parameters, 
			// from WEB.xml or provided by the Servlet container
			// e.g. parameters listed in a Tomcat 'context.xml' file
			for (String name : Collections.list(getServletContext().getInitParameterNames())) {
				addElement(retailerElement, "context-parameter", name, getServletContext().getInitParameter(name));
			}
			
			// The web application's environment variables, 
			for (Map.Entry<String, String> entry: System.getenv().entrySet()) {
				addElement(retailerElement, "environment-variable", entry.getKey(), entry.getValue());
			}				
			
			// Transform the XML document which describes the HTTP request, using the XSLT transform,
			// sending the response to the HTTP client
			DOMSource domSource = new DOMSource(requestXML);
			transformer.transform(domSource, result);
			resp.setStatus(HttpServletResponse.SC_OK);
		} catch (TransformerException xsltFailed) {
			// This runtime error would typically result from a failed HTTP request made by an 
			// XPath "document()" call.
			// To attempt to recover, Retailer modifies the XSLT's input XML document to include
			// a notification that a failure has occurred, and then re-runs the XSLT. The XSLT may
			// then decide to run in some kind of "safe mode" or produce an appropriate error 
			// notification message.
			try {
				getServletContext().log("Transform failed - retrying", xsltFailed);
				Element retailerElement = requestXML.getDocumentElement();
				// inform the XSLT of what went wrong last time
				addElement(retailerElement, "value", "previous-error", xsltFailed.getMessageAndLocation()); 
				
				DOMSource domSource = new DOMSource(requestXML);
				// Transform the XML document which describes the HTTP request, using the XSLT transform,
				// sending the response to the HTTP client
				transformerHandler.getTransformer().transform(domSource, result);
				resp.setStatus(HttpServletResponse.SC_OK);
			} catch (TransformerException retryFailed) {
				// The second try has also failed; return the error to the client
				getServletContext().log("Retry failed", retryFailed);
				resp.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
				resp.setHeader("Retry-After",  "60");
			}

		}
		os.close();		
	}
	
	// logs an exception and re-throws it as a servlet exception
	private void fail(Exception e, String message) throws ServletException {
			getServletContext().log(message, e);
			throw new ServletException(message, e);
	}
	
	private void addElement(Element parent, String type, String name, String value) {
		Element e = parent.getOwnerDocument().createElementNS(RETAILER_NS, type);
		parent.appendChild(e);
		e.setAttribute("name", name);
		e.setTextContent(value);
	}
	
	private String getCurrentDate() {
	    TimeZone tz = TimeZone.getTimeZone("UTC");
	    DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
	    df.setTimeZone(tz);
	    return df.format(new Date());
	}
		
}
