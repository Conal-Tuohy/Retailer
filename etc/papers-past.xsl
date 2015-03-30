<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns="http://www.openarchives.org/OAI/2.0/" 
xmlns:r="http://conaltuohy.com/ns/retailer/">

	<xsl:output method="xml" indent="true" media-type="application/xml"/>

	<xsl:key name="parameter" match="/r:request/r:parameter" use="@name"/>
	<xsl:key name="header" match="/r:request/r:header" use="@name"/>
	<xsl:key name="value" match="/r:request/r:value" use="@name"/>
	<xsl:variable name="key" select="
		(/r:request/r:context-parameter | /r:request/r:context-parameter)[@name='digitalnz-key'][1]
	"/>
	<xsl:variable name="page-size">100</xsl:variable><!-- Digital NZ's maximum page size=100 -->
	<xsl:variable name="base-uri" select="concat(
		'http://api.digitalnz.org/v3/records.xml',
		'?and[content_partner]=National+Library+of+New+Zealand',
		'&amp;and[primary_collection]=Papers+Past'
	)"/>
	<xsl:variable name="oai-pmh-base-uri" select="key('value', 'request-url')"/>
	<xsl:variable name="resumption-token" select="key('parameter', 'resumptionToken')"/>
	<xsl:variable name="date" select="/r:request/r:value[@name='date']"/>
	<xsl:variable name="verb" select="key('parameter', 'verb')"/>
	<xsl:variable name="from" select="key('parameter', 'from')"/>
	<xsl:variable name="until" select="key('parameter', 'until')"/>
	<xsl:variable name="from-numeric">
		<xsl:choose>
			<xsl:when test="$from">
				<xsl:value-of select="translate($from, '-T:Z', '')"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>0</xsl:text><!-- ancient times -->
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="until-numeric">
		<xsl:choose>
			<xsl:when test="$until">
				<xsl:value-of select="translate($until, '-T:Z', '')"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>30000101000000</xsl:text><!-- 3000AD; the distant future. Note, not Y3K-compliant -->
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:variable name="authentication" select="concat('api_key=', $key)"/>
	<xsl:variable name="parameters" select="/r:request/r:parameter"/>

	
	<xsl:template mode="record-header" match="/search/results/result | record">
		<header>
			<identifier><xsl:value-of select="concat('http://api.digitalnz.org/v3/records/', id)"/></identifier>
			<!--  datestamp records the last time the record changed -->
			<!-- we are using syndication-date "the date the record was added to DigitalNZ" -->
			<!-- syndication date is an ISO8601 date, but uses NZ time, whereas OAI-PMH mandates UTC
				2012-04-22T05:59:18+12:00  2012-04-22T05:59:18Z
			-->
			<datestamp><xsl:call-template name="convert-to-utc">
				<xsl:with-param name="date" select="syndication-date"/>
			</xsl:call-template></datestamp>
			<!-- the article has two collection names; one of them is "Papers Past", and other is the name of the newspaper. -->
			<!-- TODO implement query by setSpec, then enable this
			<setSpec>title:<xsl:value-of select="collection/collection[not(.='Papers Past')]"/></setSpec>
			-->
			<xsl:variable name="text-search">
				<xsl:call-template name="get-uri-parameter">
					<xsl:with-param name="parameter">text</xsl:with-param>
				</xsl:call-template>
			</xsl:variable>
			<xsl:if test="normalize-space($text-search)">
				<setSpec>search:<xsl:value-of select="$text-search"/></setSpec>
			</xsl:if>
		</header>
	</xsl:template>
	
	<xsl:template name="resumption-token">
		<xsl:param name="search-query"/>
		<xsl:variable name="complete-list-size" select="number(result-count)"/>
		<xsl:variable name="page-size" select="number(per-page)"/>
		<xsl:variable name="page" select="number(page)"/>
		<xsl:if test="$complete-list-size &gt; $page-size">
			<!-- the number of results is greater than will fit in a page, so a resumptionToken is called for -->
			<resumptionToken completeListSize="{$complete-list-size}" cursor="{$page-size* ($page - 1)}"><xsl:if test="$complete-list-size &gt; $page-size * $page">
				<!-- The pages so far have not exhausted the full list -->
				<xsl:value-of select="concat($metadataPrefix, '-', $page + 1, '-', $search-query)"/>
			</xsl:if></resumptionToken>
		</xsl:if>
	</xsl:template>
	
	<!-- utility function to parse a parameter from a URI -->
	<xsl:template name="get-uri-parameter">
		<xsl:param name="uri"/>
		<xsl:param name="parameter"/>
		<xsl:variable name="space-delimited" select="concat(translate($uri, '&amp;?', '  '), ' ')"/>
		<xsl:value-of select="substring-before(substring-after($space-delimited, concat(' ', $parameter, '=')), ' ')"/>
	</xsl:template>
	
	<xsl:template name="convert-to-utc">
		<!-- NZ time is either UTC+12 or UTC+13 in summer -->
		<!-- OAI-PMH mandates the use of UTC -->
		<!-- A quick and dirty hack is just to change the time zone without altering the date -->
		<xsl:param name="date"/>
		<xsl:value-of select="concat(substring-before($date, '+'), 'Z')"/>
	</xsl:template>

	<!-- Determine which metadata format to render;
	this is specified either as a metadataPrefix URI parameter, 
	or if there's a resumptionToken, then it's encoded as the 
	first part of that token, before the comma -->
	
	<xsl:variable name="metadataPrefix" select="
		concat(
			$parameters[@name='metadataPrefix'],
			substring-before(
				$parameters[@name='resumptionToken'], 
				'-'
			)
		)
	"/>
	
	
	<!-- transform the response from upstream into OAI-PMH XML-->
	<!-- there are two possible responses: a "search" response and a "record" response used by GetRecord -->
	<xsl:template name="render-record">
		<record>
			<xsl:apply-templates select="." mode="record-header"/>
			<metadata>
				<!-- Render every article in the requested metadataFormat -->
				<xsl:choose>
					<xsl:when test="$metadataPrefix = 'digitalnz' ">
						<xsl:apply-templates mode="digitalnz-metadata-format" select="."/>
					</xsl:when>
					<xsl:when test="$metadataPrefix = 'html' ">
						<xsl:apply-templates mode="html-metadata-format" select="."/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:apply-templates mode="oai_dc-metadata-format" select="."/>
					</xsl:otherwise>
				</xsl:choose>
			</metadata>
		</record>    
	</xsl:template>
	<xsl:template match="record">
		<!-- verb is always GetRecord -->
		<GetRecord>
			<xsl:call-template name="render-record"/>
		</GetRecord>
	</xsl:template>
	<xsl:template match="search">
		<xsl:variable name="search-query">
			<xsl:call-template name="get-uri-parameter">
				<xsl:with-param name="uri" select="request-url"/>
				<xsl:with-param name="parameter" select="'text'"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$verb = 'ListRecords'">
				<!-- the response consists a list of newspaper articles -->
				<xsl:variable name="results-in-range" select="results/result[
					translate(substring(syndication-date, 1, 19), '-T:', '') &gt; $from-numeric and
					translate(substring(syndication-date, 1, 19), '-T:', '') &lt; $until-numeric
				]"/>
				<xsl:choose>
					<xsl:when test="$results-in-range">
						<ListRecords>
							<xsl:for-each select="$results-in-range">
								<xsl:call-template name="render-record"/>
							</xsl:for-each>
							<!-- no resumption token if list exhausted in the first page -->
							<xsl:if test="
								$resumption-token or 
								translate(substring($results-in-range[$page-size]/syndication-date, 1, 19), '-T:', '') &lt; $until-numeric
							">
								<xsl:call-template name="resumption-token">
									<xsl:with-param name="search-query" select="$search-query"/>
								</xsl:call-template>
							</xsl:if>
						</ListRecords>
					</xsl:when>
					<xsl:when test="$resumption-token">
						<!-- this response is a resumed list, but unfortunately the last partial list must have
						exhausted the list. Now we have nothing to return, though it would be wrong to throw a
						noRecordsMatch exception. So instead, we return a deletion tombstone for a bogus record, 
						(which the harvester will then ignore) and signal the end of the list. -->
						<ListRecords>
							<record>
								<header status="deleted">
									<identifier>tag:conaltuohy.com,2014:evanescent</identifier>
									<datestamp><xsl:value-of select="$until"/></datestamp>
								</header>
							</record>
							<!-- empty resumption token ⇒ list is at an end -->
							<resumptionToken/>
						</ListRecords>
					</xsl:when>
					<xsl:otherwise>
						<error code="noRecordsMatch"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:when test="$verb = 'ListIdentifiers'">
				<!-- the response consists a list of newspaper articles -->
				<ListIdentifiers>
					<xsl:for-each select="results/result">
						<xsl:apply-templates select="." mode="record-header"/>
					</xsl:for-each>
					<xsl:call-template name="resumption-token">
						<xsl:with-param name="search-query" select="$search-query"/>
					</xsl:call-template>
				</ListIdentifiers>
			</xsl:when>
			<xsl:when test="$verb = 'ListSets'">
				<!-- the response consists a list of newspaper titles -->
				<ListSets>
					<set>
						 <setSpec>search:example</setSpec>
						 <setName>example</setName>
						 <setDescription>
							<oai_dc:dc 
								xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
								xmlns:dc="http://purl.org/dc/elements/1.1/" 
								xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
								xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
								http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
								<dc:description>Use "search:example" to harvest all articles that match the search query "example"</dc:description>
							 </oai_dc:dc>
						 </setDescription>
					</set>
					<!-- TODO implement query by setSpec, then enable this

					<xsl:for-each select="facets/facet[name='collection']/values/value[not(name='Papers Past')]">
						<set>
						    <setSpec>title:<xsl:value-of select="name"/></setSpec>
						    <setName><xsl:value-of select="name"/></setName>
						    <setDescription>
						    	<oai_dc:dc 
									xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
									xmlns:dc="http://purl.org/dc/elements/1.1/" 
									xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
									xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
									http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
									<dc:description>Full text of <xsl:value-of select="count"/> articles from "<xsl:value-of select="name"/>"</dc:description>
						       </oai_dc:dc>
						    </setDescription>
						</set>
					</xsl:for-each>
					-->
				</ListSets>
			</xsl:when>
			<xsl:when test="$verb = 'Identify'">
				<Identify>
					<repositoryName>Papers Past</repositoryName>
					<baseURL><xsl:value-of select="$oai-pmh-base-uri"/></baseURL>
					<protocolVersion>2.0</protocolVersion>
					<adminEmail>conal.tuohy@gmail.com</adminEmail>
					<earliestDatestamp><xsl:call-template name="convert-to-utc">
						<xsl:with-param name="date" select="results/result/syndication-date"/>
					</xsl:call-template></earliestDatestamp>
					<deletedRecord>transient</deletedRecord>
					<granularity>YYYY-MM-DDThh:mm:ssZ</granularity>
					<!-- TODO -->
					<!-- <compression>deflate</compression> -->
					<!-- TODO rights statements, etc -->
				</Identify>
			</xsl:when>
			<xsl:otherwise>
				<!-- The remaining verb - ListMetadataFormats - is not processed by 
				querying the server upstream and transforming the result of the query; 
				instead a static piece of OAI XML is used, requiring no transformation -->
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template match="result | record" mode="oai_dc-metadata-format">
		<oai_dc:dc 
			xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
			xmlns:dc="http://purl.org/dc/elements/1.1/" 
			xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
			xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
			http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
     			<xsl:for-each select="title"><dc:title><xsl:value-of select="."/></dc:title></xsl:for-each>
     			<xsl:for-each select="source-url"><dc:identifier><xsl:value-of select="."/></dc:identifier></xsl:for-each>
			<dc:type>text</dc:type>
       		<dc:source><xsl:value-of select="collection-title/collection-title[not(.='Papers Past')]"/></dc:source>
       		<dc:date><xsl:value-of select="date/date"/></dc:date>
       	</oai_dc:dc>
	</xsl:template>
	
	<xsl:template match="result | record" mode="html-metadata-format">
		<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en"
      			xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      			xsi:schemaLocation="http://www.w3.org/1999/xhtml http://www.w3.org/2002/08/xhtml/xhtml1-strict.xsd">
      			<head profile="http://dublincore.org/documents/2008/08/04/dc-html/">
      				<title><xsl:value-of select="title"/></title>
      				<link rel="Alternate" href="{source-url}"/>
      				<link rel="schema.DC" href="http://purl.org/dc/elements/1.1/"/>
      				<meta name="DC.source" content="{collection-title/collection-title[not(.='Papers Past')]}"/>
      				<meta name="DC.date" content="{date/date}"/>
      			</head>
      			<body>
      				<div>
					<xsl:call-template name="unquote-html">
						<xsl:with-param name="text" select="fulltext"/>
						<xsl:with-param name="headline" select="substring-before(title, ' (')"/>
						<xsl:with-param name="link" select="source-url"/>
					</xsl:call-template>
				</div>
      			</body>
       	</html>
	</xsl:template>	

	<!-- parse the OAI-PMH request, check for syntax errors, generate response content and pass it for transformation -->
	
	<xsl:template match="/r:request">
		<xsl:choose>
			<xsl:when test="not($key)">
				<error>You must provide your DigitalNZ API key as a servlet init-param named "digitalnz-key"</error>
			</xsl:when>
			<xsl:otherwise>
				 <OAI-PMH 
						xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
						xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
					<responseDate><xsl:value-of select="$date"/></responseDate>
					<!-- check for syntax errors in query received from harvester -->
					<xsl:variable name="errors">
						<xsl:apply-templates mode="validate-request" select="."/>
					</xsl:variable>
						<xsl:choose>
						<xsl:when test="normalize-space($errors)">
							<!-- errors detected - return base URI without query parameters, and the list of errors -->
							<request><xsl:value-of select="$oai-pmh-base-uri"/></request>
							<xsl:copy-of select="$errors"/>
						</xsl:when>
						<xsl:otherwise>
							<!-- no errors detected - return base URI and the validated query parameters, and the result of handling the verb -->	
							<request>
								<xsl:for-each select="/r:request/r:parameter">
									<xsl:attribute name="{@name}">
										<xsl:value-of select="."/>
									</xsl:attribute>         		
								</xsl:for-each>		
								<xsl:value-of select="$oai-pmh-base-uri"/>
							</request>		
							<!-- delegate to verb handlers here (NB they may generate <error> elements) -->
							<xsl:apply-templates select="r:parameter[@name='verb']"/>
						</xsl:otherwise>
					</xsl:choose>
				</OAI-PMH>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- detection of syntax errors -->
	<xsl:template mode="validate-request" match="r:request">
		<!-- generate <error> elements for any syntactic errors in the request-->
		<!--  see http://www.openarchives.org/OAI/openarchivesprotocol.html#ErrorConditions 
		for the list of errors to be covered below. -->
		
		<!-- The various verbs have their own required arguments: -->
		<xsl:choose>
			<xsl:when test="r:parameter[@name='verb'] = 'GetRecord'">
				<!-- badArgument - The request includes illegal arguments or is missing required arguments. -->
				<xsl:call-template name="check-arguments">
					<xsl:with-param name="required">identifier metadataPrefix</xsl:with-param>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="r:parameter[@name='verb'] = 'ListRecords' or r:parameter[@name='verb'] = 'ListIdentifiers'  ">
				<xsl:call-template name="check-arguments">
					<xsl:with-param name="required">metadataPrefix</xsl:with-param>
					<xsl:with-param name="optional">from until set</xsl:with-param>
					<xsl:with-param name="exclusive">resumptionToken</xsl:with-param>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="r:parameter[@name='verb'] = 'Identify'">
				<xsl:call-template name="check-arguments"/><!-- no arguments -->
			</xsl:when>
			<xsl:when test="r:parameter[@name='verb'] = 'ListMetadataFormats'">
				<xsl:call-template name="check-arguments">
					<xsl:with-param name="optional">identifier</xsl:with-param>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="r:parameter[@name='verb' ]= 'ListSets'">
				<xsl:call-template name="check-arguments">
					<xsl:with-param name="exclusive">resumptionToken</xsl:with-param>
				</xsl:call-template>
			</xsl:when>
		</xsl:choose>
				
		<!-- TODO check validity of syntax of argument values -->

		<!--  repeated arguments are not allowed -->
		<xsl:variable name="repeated-arguments" select="r:parameter[@name=preceding-sibling::r:parameter/@name]"/>
		<xsl:for-each select="$repeated-arguments[not(@name='verb')]">
			<error code="badArgument">The  '<xsl:value-of select="@name"/>' argument is repeated</error>
		</xsl:for-each>
		<xsl:for-each select="$repeated-arguments[@name='verb']">
			<error code="badVerb">The 'verb' argument is repeated</error>
		</xsl:for-each>
		
		<!-- badResumptionToken - resumptionToken syntax is not statically checked,
			though badResumptionToken could be caught from upstream and rethrown. -->
			
		<!-- any verb argument must be one of the six known OAI-PMH 2.0 verbs -->
		<xsl:variable name="badVerb" select="
			r:parameter
				[@name='verb']
				[not(
					. = 'GetRecord' or 
					. = 'Identify' or 
					. = 'ListIdentifiers' or 
					. = 'ListMetadataFormats' or 
					. = 'ListRecords' or 
					. = 'ListSets'
				)]
		"/>
		<xsl:for-each select="$badVerb">
			<error code="badVerb">The verb '<xsl:value-of select="@name"/>' is invalid</error>
		</xsl:for-each>
			
		<!-- The 'verb' argument is always required -->
		<xsl:if test="not(r:parameter[@name='verb'])">
			<error code="badVerb">The 'verb' argument is missing</error>
		</xsl:if>
		
		<!-- Only oai_dc, html, and digitalnz metadata prefixes are known to this server; any other prefixes produce cannotDisseminateFormat -->
		<!-- However, noMetadataFormats is never thrown because every record can be disseminated in those two formats -->
		<xsl:variable name="unsupported-metadata-prefix" select="
			r:parameter
				[@name='metadataPrefix']
				[not( .='oai_dc' or .='digitalnz' or .='html')]"
		/>
		<xsl:for-each select="$unsupported-metadata-prefix">
			<error code="cannotDisseminateFormat">Unsupported metadata prefix '<xsl:value-of select="."/>'</error>
		</xsl:for-each>
		
		<!-- idDoesNotExist is never thrown from static validation of an id, but only as a runtime exception in response to an upstream failure -->
		
		<!-- noRecordsMatch only thrown by upstream, caught and rethrown as a runtime exception in ListRecords/ListIdentifiers handler -->
		
		<!-- noSetHierarchy exception is never reported because we do support sets -->
		
	</xsl:template>
	
	<xsl:template name="check-arguments">
		<xsl:param name="required" select="''"/>
		<xsl:param name="optional" select="''"/>
		<xsl:param name="exclusive" select="''"/>
		<!-- 
		<debug>
			check-arguments:
 			required: '<xsl:value-of select="$required"/>'
			optional: '<xsl:value-of select="$optional"/>'
			exclusive: '<xsl:value-of select="$exclusive"/>'
		</debug>
		 -->
		 <xsl:choose>
			<xsl:when test="$parameters[@name=$exclusive]">
				<!--  exclusive parameter is present; check that all other parameters are not -->
				<!--  <xsl:message>exclusive parameter present</xsl:message>-->
				<xsl:call-template name="check-illegal-arguments">
					<xsl:with-param name="legal-arguments" select="$exclusive"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<!--  exclusive parameter absent; all other required parameters must be present -->			
				<!-- <xsl:message>no exclusive parameter present</xsl:message>		 -->
				<xsl:call-template name="check-arguments-exist">
					<xsl:with-param name="arguments" select="$required"/>
				</xsl:call-template>
				<!-- check arguments against a whitelist -->
				<xsl:call-template name="check-illegal-arguments">
					<xsl:with-param name="legal-arguments" select="concat($optional , ' ' , $required)"/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template name="check-arguments-exist">
		<xsl:param name="arguments"/>
		<xsl:variable name="argument" select="substring-before(concat($arguments, ' '), ' ')"/>
		<xsl:if test="$argument">
			<!-- 
			<debug>arguments: '<xsl:value-of select="$arguments"/>', first argument: '<xsl:value-of select="$argument"/>'</debug>
			 -->
			<xsl:if test="not( $parameters[@name = $argument] )">
				<error code="badArgument">Required argument '<xsl:value-of select="$argument"/>' is missing</error>
			</xsl:if>
			<xsl:call-template name="check-arguments-exist">
				<xsl:with-param name="arguments" select="substring-after($arguments, ' ')"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	
	<xsl:template name="check-illegal-arguments">
		<xsl:param name="legal-arguments"/>
		<xsl:for-each select="$parameters">
			<xsl:if test="@name != 'verb' and not(contains($legal-arguments, @name))">
				<error code="badArgument">Illegal argument '<xsl:value-of select="@name"/>'</error>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
		
	<xsl:template match="r:parameter[@name='verb' and .='ListSets']">
		<!-- NB our ListSets does not bother with a resumptionToken because Digital NZ lists all newspaper titles in a single page -->
		<xsl:call-template name="transform-document">
			<xsl:with-param name="label">Digital NZ URI of list of newspaper titles</xsl:with-param>
			<!-- 
				The URI identifies the set of all articles, 
				• including the newspaper titles they are from ("facets=collection")
				• but excluding details of the individual articles ("per-page=0")
			-->
			<xsl:with-param name="document-uri" select="concat(
				$base-uri, 
				'&amp;per-page=0&amp;facets=collection', 
				'&amp;', $authentication
			)"/>
		</xsl:call-template>
	</xsl:template>
	
	<xsl:template name="transform-document">
		<xsl:param name="document-uri"/>
		<xsl:param name="label" select=" 'Trove URI' "/>
		<xsl:message><xsl:value-of select="concat($label, ': ', $document-uri)"/></xsl:message>
		<xsl:apply-templates select="document($document-uri)"/>
	</xsl:template>
	
	<xsl:template match="r:parameter[@name='verb' and .='GetRecord']">
		<!-- 
		e.g. http://api.digitalnz.org/v3/records/9862604
		NB the value of the "identifier" parameter is a full URI - not relative!
		-->
		<xsl:call-template name="transform-document">
			<xsl:with-param name="label">Digital NZ URI of individual article</xsl:with-param>
			<xsl:with-param name="document-uri" select="concat(key('parameter', 'identifier'), '.xml?', $authentication)"/>
		</xsl:call-template>		
	</xsl:template>
	
	<xsl:template match="r:parameter[@name='verb' and .='ListMetadataFormats']">
		<ListMetadataFormats>
			<metadataFormat>
				<metadataPrefix>oai_dc</metadataPrefix>
				<schema>http://www.openarchives.org/OAI/2.0/oai_dc.xsd
				</schema>
				<metadataNamespace>http://www.openarchives.org/OAI/2.0/oai_dc/</metadataNamespace>
			</metadataFormat>
			<metadataFormat>
				<metadataPrefix>html</metadataPrefix>
				<schema>http://www.w3.org/2002/08/xhtml/xhtml1-strict.xsd</schema>
				<metadataNamespace>http://www.w3.org/1999/xhtml</metadataNamespace>
			</metadataFormat>
			<metadataFormat>
				<metadataPrefix>digitalnz</metadataPrefix>
				<schema>digitalnz.xsd</schema><!-- TODO -->
				<metadataNamespace>http://digitalnz.org/developers/api-docs-v3</metadataNamespace>
			</metadataFormat>
		</ListMetadataFormats>
	</xsl:template>
	
	<xsl:template match="r:parameter[@name='verb' and (.='ListRecords'  or .='ListIdentifiers' )]">
			<!-- ListRecords and ListIdentifiers have:
				* EITHER a resumptionToken
				* OR a metadataPrefix, plus optional "set", "from" and "until" -->
			<xsl:variable name="resumption-token" select="$parameters[@name='resumptionToken']"/>
			<xsl:choose>
				<xsl:when test="$resumption-token">
					<xsl:variable name="metadata-prefix" select="substring-before($resumption-token, '-')"/>
					<xsl:variable name="page-number" select="substring-before(substring-after($resumption-token, '-'), '-')"/>
					<xsl:variable name="search" select="substring-after(substring-after($resumption-token, '-'), '-')"/>
					<xsl:variable name="search-query">
						<xsl:if test="$search">
							<xsl:text>&amp;text=</xsl:text>
							<xsl:value-of select="$search"/>
							<!--
							<xsl:call-template name="encode-for-uri">
								<xsl:with-param name="text" select="$search"/>
							</xsl:call-template>
							-->
						</xsl:if>
					</xsl:variable>
					<xsl:call-template name="transform-document">
						<xsl:with-param name="label">Digital NZ URI for the next part of the list</xsl:with-param>
						<xsl:with-param name="document-uri" select="
							concat(
								$base-uri, 
								$search-query,
								'&amp;per_page=', $page-size,
								'&amp;page=', $page-number,
								'&amp;', $authentication
							)
						"/>		
					</xsl:call-template>		
				</xsl:when>
				<xsl:otherwise>
					<!-- 
						No resumptionToken ⇒ this is the first request in a sequence.
						We have to parse OAI-PMH query parameters.
					-->
					<xsl:variable name="search-query">
						<xsl:if test="starts-with($parameters[@name='set'], 'search:')">
							<xsl:text>&amp;text=</xsl:text>
							<xsl:call-template name="encode-for-uri">
								<xsl:with-param name="text" select="substring-after($parameters[@name='set'], 'search:')"/>
							</xsl:call-template>
						</xsl:if>
					</xsl:variable>
					<!-- TODO implement title query as a constraint on the "collection" facet -->
					<!--
					<xsl:variable name="title-query">
						<xsl:if test="starts-with($parameters[@name='set'], 'title:')">
							<xsl:text>&amp;l-title=</xsl:text>
							<xsl:value-of select="substring-after($parameters[@name='set'], 'title:')"/>
						</xsl:if>
					</xsl:variable>
					-->
					<xsl:choose>
						<xsl:when test="key('parameter', 'from')">
							<!-- querying starting from a particular date -->
							<xsl:variable name="latest-record-uri" select="
								concat(
									$base-uri, 
									$search-query,
									'&amp;per_page=1&amp;direction=desc&amp;sort=syndication_date',
									'&amp;', $authentication
								)
							"/>
							<xsl:variable name="latest-record-response" select="document($latest-record-uri)"/>
							<xsl:variable name="latest-record-date">
								<xsl:call-template name="convert-to-utc">
									<xsl:with-param name="date" select="$latest-record-response/search/results/result/syndication-date"/>
								</xsl:call-template>
							</xsl:variable>
							<xsl:message>latest-record-date=<xsl:value-of select="$latest-record-date"/></xsl:message>
							<xsl:message>from = <xsl:value-of select="key('parameter', 'from')"/></xsl:message>							<xsl:message>last record new = <xsl:value-of select="$latest-record-date &gt; key('parameter', 'from')"/></xsl:message>
							<xsl:choose>
								<!-- are there any records recent enough? -->
								<xsl:when test="translate($latest-record-date, '-T:Z', '') &gt; translate(key('parameter', 'from'), '-T:Z', '')">
									<!-- the last record, at least, is new -->
									<!--
									Here we must perform a binary search of the set of results, to find the page number of the results page in which the date range begins
									-->
									<xsl:message>latest record, at least, is new</xsl:message>
									<xsl:variable name="earliest-record-uri" select="
										concat(
											$base-uri, 
											$search-query,
											'&amp;per_page=1&amp;direction=asc&amp;sort=syndication_date',
											'&amp;', $authentication
										)
									"/>
									<xsl:variable name="earliest-record-response" select="document($earliest-record-uri)"/>
									<xsl:variable name="earliest-record-date">
										<xsl:call-template name="convert-to-utc">
											<xsl:with-param name="date" select="$earliest-record-response/search/results/result/syndication-date"/>
										</xsl:call-template>
									</xsl:variable>
									<!-- The "from" date may be earlier than the earliest date, in which case we can just start at the beginning,
									otherwise we need to search for a later start record 
									-->
									<xsl:message>earliest-record-date=<xsl:value-of select="$earliest-record-date"/></xsl:message>
									<xsl:choose>
										<xsl:when test="translate($earliest-record-date, '-T:Z', '') &gt; translate(key('parameter', 'from'), '-T:Z', '')">
											<!-- qaz start at beginning -->
											<!-- see below - this is the same result as when a request was received with no "from" date -->
											<xsl:message>"from" date is earlier than the earliest record</xsl:message>
										</xsl:when>
										<xsl:otherwise>
											<!-- Search for a better starting record. 
											We want to request a page which includes the first record matching, or later than, the "from" date.
											-->
											<xsl:message>"from" date is between the earliest and latest records</xsl:message>
											<xsl:variable name="start-page">
												<xsl:call-template name="get-date-start-page">
													<xsl:with-param name="search-query" select="$search-query"/>
													<xsl:with-param name="date" select="key('parameter', 'from')"/>
													<xsl:with-param name="start-index" select="1"/>
													<xsl:with-param name="end-index" select="$latest-record-response/search/result-count"/>
												</xsl:call-template>
											</xsl:variable>
											<xsl:call-template name="transform-document">
												<xsl:with-param name="label">Digital NZ URI for the beginning of a list starting at a specified date</xsl:with-param>
												<xsl:with-param name="document-uri" select="
													concat(
														$base-uri, 
														$search-query,
														'&amp;page=', $start-page,
														'&amp;per_page=', $page-size,
														'&amp;direction=asc&amp;sort=syndication_date',
														'&amp;', $authentication
													)
												"/>
											</xsl:call-template>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:when>
								<xsl:otherwise>
									<!-- there are no new records -->
									<error code="noRecordsMatch"/>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:when>
						<xsl:otherwise>
							<!-- not starting at any particular date -->
							<xsl:call-template name="transform-document">
								<xsl:with-param name="label">Digital NZ URI for the beginning of a list of records irrespective of their dates</xsl:with-param>
								<xsl:with-param name="document-uri" select="
									concat(
										$base-uri, 
										$search-query,
										'&amp;per_page=', $page-size,
										'&amp;', $authentication
									)
								"/>
							</xsl:call-template>		
						</xsl:otherwise>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:template>	
		
	<xsl:template name="get-date-start-page">
		<xsl:param name="search-query"/><!-- search query parameters -->
		<xsl:param name="date"/>
		<!-- index (counting in chronological order) of the earliest known record which is later than $date -->
		<xsl:param name="end-index"/>
		<!-- index (counting in chronological order) of the latest known record which is earlier than $date -->
		<xsl:param name="start-index"/>
		<!-- Return the page number of the first page to include the date -->
		<!-- NB the latest article may be older that the date, in which case there's no need to make any other requests upstream. -->
		<!-- Otherwise, we need to search backward until we find an article older than the date. -->
		<!-- Strategies for the search, to minimise the number of HTTP calls:
			A naive binary search through x records by equal bisection will be O(log₂(x)) if the request dates are distributed uniformly within the timeframe, but in general request dates will tend to be very recent dates, not old ones. Typical usage is for the request date to be 24 hours before the current date. 
			Another approach might be to search backwards by first subtracting $page-size records, and if that's not enough, doubling the decrement.
			Another approach would be to assume records are evenly spaced in time, and estimate a record index from the ratio of the target date and the end-point dates.
		-->
		<!-- the size of the range of records in which the "from" date falls -->
		<xsl:variable name="range" select="$end-index - $start-index"/>
		<xsl:message>get-date-start-page; date=<xsl:value-of select="$date"/>, end-index=<xsl:value-of select="$end-index"/>, start-index=<xsl:value-of select="$start-index"/></xsl:message>
		<xsl:choose>
			<xsl:when test="2 * $range &gt; $page-size">
				<!-- the range is too large to request as a page, so we need to divide it up by probing a midpoint and 
				then using that midpoint as either the start or end of the range -->
				<xsl:variable name="midpoint-index" select="floor(($start-index + $end-index) div 2)"/>
				<xsl:variable name="midpoint-record-uri" select="
					concat(
						$base-uri, 
						$search-query,
						'&amp;page=', $midpoint-index,
						'&amp;per_page=1&amp;direction=asc&amp;sort=syndication_date',
						'&amp;', $authentication
					)
				"/>
				<xsl:message>midpoint-record-uri=<xsl:value-of select="$midpoint-record-uri"/></xsl:message>
				<xsl:variable name="midpoint-record-response" select="document($midpoint-record-uri)"/>
				<xsl:variable name="midpoint-record-date">
					<xsl:call-template name="convert-to-utc">
						<xsl:with-param name="date" select="$midpoint-record-response/search/results/result/syndication-date"/>
					</xsl:call-template>
				</xsl:variable>
				<xsl:choose>
					<!-- qaz check date logic -->
					<xsl:when test="$midpoint-record-date &gt; $date">
						<!-- the midpoint of the range is later than our target date, so replace the end index of our range with the midpoint -->
						<xsl:call-template name="get-date-start-page">
							<xsl:with-param name="search-query" select="$search-query"/>
							<xsl:with-param name="date" select="$date"/>
							<xsl:with-param name="start-index" select="$start-index"/>
							<xsl:with-param name="end-index" select="$midpoint-index"/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>
						<!-- the midpoint of the range is not later than our target date, so replace the start index of our range with the midpoint -->
						<xsl:call-template name="get-date-start-page">
							<xsl:with-param name="search-query" select="$search-query"/>
							<xsl:with-param name="date" select="$date"/>
							<xsl:with-param name="start-index" select="$midpoint-index"/>
							<xsl:with-param name="end-index" select="$end-index"/>
						</xsl:call-template>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<!-- the range is small enough to be requested as a single page -->
				<xsl:value-of select="floor(($start-index + 1) div $page-size)"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
		
	<!-- generate an Identify statement -->
	<xsl:template match="r:parameter[@name='verb' and .='Identify']">
		<!-- we need to know the date of the oldest record in Digital NZ to complete an Identify statement -->
		<xsl:call-template name="transform-document">
			<xsl:with-param name="label">Digital NZ URI to find the earliest article</xsl:with-param>
			<!-- 
			The URI identifies the oldest article = the first article in ascending order of syndication date
			-->
			<xsl:with-param name="document-uri" select="
				concat(
					$base-uri, 
					'&amp;per_page=1&amp;direction=asc&amp;sort=syndication_date',
					'&amp;', $authentication
				)
			"/>
		</xsl:call-template>
	</xsl:template>

	<!-- The OAI-PMH spec says metadata schemas must use XML namespaces. -->
	<xsl:template match="article" mode="digitalnz-metadata-format">
		<article xmlns="http://digitalnz.org/developers/api-docs-v3" >
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates mode="digitalnz-metadata-format"/>
		</article>
	</xsl:template>
	
	<xsl:template match="*" mode="digitalnz-metadata-format">
		<xsl:element name="{local-name(.)}" xmlns="http://digitalnz.org/developers/api-docs-v3" >
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates mode="digitalnz-metadata-format"/>
		</xsl:element>
	</xsl:template>
	
	<xsl:template match="fulltext" mode="digitalnz-metadata-format">
		<xsl:element name="{local-name(.)}" xmlns="http://digitalnz.org/developers/api-docs-v3">
			<xsl:copy-of select="@*"/>
			<div xmlns="http://www.w3.org/1999/xhtml">
				<xsl:call-template name="unquote-html">
					<xsl:with-param name="text" select="."/>
					<xsl:with-param name="headline" select="substring-before(../title, ' (')"/>
				</xsl:call-template>
			</div>
		</xsl:element>
	</xsl:template>
	
	<xsl:template name="unquote-html">
		<xsl:param name="text"/>	
		<xsl:param name="headline"/>
		<xsl:param name="link"/>
		<!-- break the headline out into an h1 -->
		<xsl:element name="h1" xmlns="http://www.w3.org/1999/xhtml">
			<xsl:element name="a">
				<xsl:attribute name="href">
					<xsl:value-of select="$link"/>
				</xsl:attribute>
				<xsl:value-of select="$headline"/>
			</xsl:element>
		</xsl:element>
		<!-- remove the headline from the text (we don't want it duplicated) -->
		<!-- NB the text is all lower case without punctuation, whereas the headline may be in caps and have punctuation -->
		<xsl:variable name="upper" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>
		<xsl:variable name="lower" select="'abcdefghijklmnopqrstuvwxyz'"/>
		<xsl:variable name="lower-case-headline" select="
			translate(
				$headline,
				$upper,
				$lower
			)
		"/>
		<xsl:variable name="punctuation-in-headline" select="
			translate(
				$lower-case-headline, 
				concat(' ', $lower), 
				''
			)
		"/>
		<xsl:variable name="headline-as-it-would-appear-in-text" select="
			translate(
				$lower-case-headline, 
				$punctuation-in-headline, 
				''
			)
		"/>
		<xsl:choose>
			<xsl:when test="starts-with($text, $headline-as-it-would-appear-in-text)">
				<!-- the start of the text does match the headline, so skip over it -->
				<xsl:value-of select="substring-after($text, $headline-as-it-would-appear-in-text)"/>
			</xsl:when>
			<xsl:otherwise>
				<!-- OCR errors in text may have mangled the heading? Just output the whole of the text -->
				<xsl:value-of select="$text"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	
	<xsl:template name="encode-for-uri">
		<xsl:param name="text" />
		<xsl:call-template name="find-and-replace">
			<xsl:with-param name="find" select=" '/' "/>
			<xsl:with-param name="replace" select=" '%2F' "/>
			<xsl:with-param name="text">
				<xsl:call-template name="find-and-replace">
					<xsl:with-param name="find" select=" '[' "/>
					<xsl:with-param name="replace" select=" '%5B' "/>
					<xsl:with-param name="text">
						<xsl:call-template name="find-and-replace">
							<xsl:with-param name="find" select=" ' ' "/>
							<xsl:with-param name="replace" select=" '%20' "/>
							<xsl:with-param name="text" >
								<xsl:call-template name="find-and-replace">
									<xsl:with-param name="find" select=" ':' "/>
									<xsl:with-param name="replace" select=" '%3A' "/>
									<xsl:with-param name="text">
										<xsl:call-template name="find-and-replace">
											<xsl:with-param name="find" select=" ']' "/>
											<xsl:with-param name="replace" select=" '%5D' "/>
											<xsl:with-param name="text">
												<xsl:call-template name="find-and-replace">
													<xsl:with-param name="find" select=" '&amp;' "/>
													<xsl:with-param name="replace" select=" '%26' "/>
													<xsl:with-param name="text">
														<xsl:call-template name="find-and-replace">
															<xsl:with-param name="find" select=" '=' "/>
															<xsl:with-param name="replace" select=" '%3D' "/>
															<xsl:with-param name="text">
																<xsl:call-template name="find-and-replace">
																	<xsl:with-param name="find" select=" '%' "/>
																	<xsl:with-param name="replace" select=" '%25' "/>
																	<xsl:with-param name="text" select="$text"/>
																</xsl:call-template>
															</xsl:with-param>
														</xsl:call-template>
													</xsl:with-param>
												</xsl:call-template>
											</xsl:with-param>
										</xsl:call-template>
									</xsl:with-param>
								</xsl:call-template>
							</xsl:with-param>
						</xsl:call-template>
					</xsl:with-param>
				</xsl:call-template>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:template>
		
	<xsl:template name="find-and-replace">
		<xsl:param name="find"/>
		<xsl:param name="replace"/>
		<xsl:param name="text"/>
		<xsl:choose>
			<xsl:when test="contains($text, $find)">
				<xsl:value-of select="substring-before($text, $find)"/>
				<xsl:value-of select="$replace"/>
				<xsl:call-template name="find-and-replace">
					<xsl:with-param name="find" select="$find"/>
					<xsl:with-param name="replace" select="$replace"/>
					<xsl:with-param name="text" select="substring-after($text, $find)"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$text"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

</xsl:stylesheet>
