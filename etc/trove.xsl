<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns="http://www.openarchives.org/OAI/2.0/" 
xmlns:r="http://conaltuohy.com/ns/retailer/">

	<xsl:output method="xml" indent="true"/>
	<xsl:variable name="key" select="/r:request/r:context-parameter[@name='trove-key']"/>
	<xsl:variable name="page-size">100</xsl:variable><!-- max=100 -->
	<xsl:variable name="base-uri">http://api.trove.nla.gov.au</xsl:variable>
	<xsl:variable name="oai-pmh-base-uri" select="key('value', 'uri')"/>
	<xsl:variable name="date" select="/r:request/r:value[@name='date']"/>
	<xsl:key name="parameter" match="/r:request/r:parameter" use="@name"/>
	<xsl:key name="header" match="/r:request/r:header" use="@name"/>
	<xsl:key name="value" match="/r:request/r:value" use="@name"/>
	<xsl:variable name="verb" select="key('parameter', 'verb')"/>
	<xsl:variable name="authentication" select="concat('key=', $key)"/>
	<xsl:variable name="parameters" select="/r:request/r:parameter"/>

	
	<xsl:template mode="record-header" match="article">
		<header>
			<identifier><xsl:value-of select="concat($base-uri, @url)"/></identifier>
			<!--  datestamp records the last time the record changed -->
			<datestamp><xsl:choose>
				<xsl:when test="lastCorrection">
					<!-- article has been corrected, so the record has a date of last update -->
					<xsl:value-of select="lastCorrection/@lastupdated"/>
				</xsl:when>
				<xsl:otherwise>
					<!--  article has never been manually corrected -->
					<!--  so use the publication date -->
					<!-- FIXME this doesn't deal with the case when old material is newly digitised
					and added to the corpus -->
					<xsl:value-of select="concat(date, 'T00:00:00Z')"/>
				</xsl:otherwise>
			</xsl:choose></datestamp>
			<setSpec>title:<xsl:value-of select="title/@id"/></setSpec>
		</header>
	</xsl:template>
	
	<xsl:template name="resumption-token">
		<xsl:for-each select="zone/records[@next]">
			<resumptionToken completeListSize="{@total}" cursor="{@s}"><xsl:value-of select="concat($metadataPrefix, '-', normalize-space(@next))"/></resumptionToken>
		</xsl:for-each>
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
	
	<xsl:template match="response">
		<xsl:choose>
			<xsl:when test="$verb = 'ListRecords'">
				<!-- the response consists a list of newspaper articles -->
				<ListRecords>
					<!-- list all records which have identifiers (unidentified records are part way through digitisation process -->
					<xsl:for-each select="zone/records/article[identifier]">
						<record>
							<xsl:apply-templates select="." mode="record-header"/>
							<metadata>
								<!-- Render every article in the requested metadataFormat -->
								<xsl:choose>
									<xsl:when test="$metadataPrefix = 'trove' ">
										<xsl:apply-templates mode="trove-metadata-format" select="."/>
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
					</xsl:for-each>
					<xsl:call-template name="resumption-token"/>
				</ListRecords>
			</xsl:when>
			<xsl:when test="$verb = 'ListIdentifiers'">
				<!-- the response consists a list of newspaper articles -->
				<ListIdentifiers>
					<xsl:for-each select="zone/records/article">
						<xsl:apply-templates select="." mode="record-header"/>
					</xsl:for-each>
					<xsl:call-template name="resumption-token"/>
				</ListIdentifiers>
			</xsl:when>
			<xsl:when test="$verb = 'ListSets'">
				<!-- the response consists a list of newspaper titles -->
				<ListSets>
					<xsl:for-each select="records/newspaper">
						<set>
						    <setSpec>title:<xsl:value-of select="@id"/></setSpec>
	    					<setName><xsl:value-of select="title"/></setName>
						    <setDescription>
						    	<oai_dc:dc 
									xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
									xmlns:dc="http://purl.org/dc/elements/1.1/" 
									xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
									xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
									http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
									<dc:description>Full text of articles from "<xsl:value-of select="title"/>"</dc:description>
									<xsl:for-each select="issn">
										<dc:identifier>urn:issn:<xsl:value-of select="."/></dc:identifier>
									</xsl:for-each>
									<xsl:for-each select="troveUrl">
										<dc:identifier><xsl:value-of select="."/></dc:identifier>
									</xsl:for-each>
						       </oai_dc:dc>
						    </setDescription>
						</set>
					</xsl:for-each>
					<xsl:call-template name="resumption-token"/>
				</ListSets>
			</xsl:when>
			<xsl:when test="$verb = 'Identify'">
				<Identify>
					<repositoryName>Trove Newspapers</repositoryName>
					<baseURL><xsl:value-of select="$oai-pmh-base-uri"/></baseURL>
					<protocolVersion>2.0</protocolVersion>
					<adminEmail>conal.tuohy@gmail.com</adminEmail>
					<earliestDatestamp><xsl:value-of select="zone/records/article/date"/>T00:00:00Z</earliestDatestamp>
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
	
	<xsl:template match="article" mode="oai_dc-metadata-format">
		<oai_dc:dc 
			xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
			xmlns:dc="http://purl.org/dc/elements/1.1/" 
			xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
			xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
			http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
     		<xsl:for-each select="heading"><dc:title><xsl:value-of select="."/></dc:title></xsl:for-each>
     		<xsl:for-each select="identifier"><dc:identifier><xsl:value-of select="."/></dc:identifier></xsl:for-each>
       		<dc:type>text</dc:type>
       		<xsl:if test=" illustrated = 'Y' "><dc:type>image</dc:type></xsl:if>
       		<dc:source><xsl:value-of select="title"/></dc:source>
       		<dc:date><xsl:value-of select="date"/></dc:date>
       	</oai_dc:dc>
	</xsl:template>
	
	<xsl:template match="article" mode="html-metadata-format">
		<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en"
      			xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      			xsi:schemaLocation="http://www.w3.org/1999/xhtml http://www.w3.org/2002/08/xhtml/xhtml1-strict.xsd">
      			<head profile="http://dublincore.org/documents/2008/08/04/dc-html/">
      				<title><xsl:value-of select="heading"/></title>
      				<link rel="Alternate" href="{trovePageUrl}"/>
      				<link rel="schema.DC" href="http://purl.org/dc/elements/1.1/"/>
      				<meta name="DC.source" content="{title}"/>
      				<meta name="DC.date" content="{date}"/>
      			</head>
      			<body>
      				<xsl:call-template name="unquote-html">
      					<xsl:with-param name="text" select="articleText"/>
      				</xsl:call-template>
      			</body>
       	</html>
	</xsl:template>	

	<!-- parse the OAI-PMH request, check for syntax errors, generate response content and pass it for transformation -->
	
	<!-- <HTML></HTML> accompanied by an HTTP Refresh header appears to be a Trove load-shedding mechanism-->
	<xsl:template match="/HTML">
		<!-- Terminate the XSLT, allowing the Servlet to retry -->
		<xsl:message terminate="yes">Received fob-off from Trove</xsl:message>
	</xsl:template>
	
	<xsl:template match="/r:request">
		<xsl:choose>
			<xsl:when test="not($key)">
				<error>You must provide your Trove API key as a servlet init-param named "trove-key"</error>
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
		
		<!-- Only oai_dc and trove metadata prefixes are known to this server; any other prefixes produce cannotDisseminateFormat -->
		<!-- However, noMetadataFormats is never thrown because every record can be disseminated in those two formats -->
		<xsl:variable name="unsupported-metadata-prefix" select="
			r:parameter
				[@name='metadataPrefix']
				[not( .='oai_dc' or .='trove' or .='html')]"
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
			<!-- NB our ListSets does not bother with a resumptionToken because Trove lists all newspaper titles in a single page -->
			<xsl:call-template name="transform-document">
				<xsl:with-param name="label">Trove URI of list of newspaper titles</xsl:with-param>
				<xsl:with-param name="document-uri" select="concat($base-uri, '/newspaper/titles?', $authentication)"/>
			</xsl:call-template>
	</xsl:template>
	
	<xsl:template name="transform-document">
		<xsl:param name="document-uri"/>
		<xsl:param name="label" select=" 'Trove URI' "/>
		<!--
		<xsl:comment><xsl:value-of select="concat($label, ': ', $document-uri)"/></xsl:comment>
		
		-->
		<xsl:message><xsl:value-of select="concat($label, ': ', $document-uri)"/></xsl:message>
		<xsl:apply-templates select="document($document-uri)"/>
	</xsl:template>
	
	<xsl:template match="r:parameter[@name='verb' and .='GetRecord']">
		<!-- 
		e.g. http://api.trove.nla.gov.au/newspaper/18342701
		NB the value of the "identifier" parameter is a full URI - not relative!
		-->
		<xsl:call-template name="transform-document">
			<xsl:with-param name="label">Trove URI of individual article</xsl:with-param>
			<xsl:with-param name="document-uri" select="concat(key('parameter', 'identifier'), '&amp;', $authentication)"/>
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
				<metadataPrefix>trove</metadataPrefix>
				<schema>trove.xsd</schema><!-- TODO -->
				<metadataNamespace>http://api.trove.nla.gov.au/</metadataNamespace>
			</metadataFormat>
		</ListMetadataFormats>
	</xsl:template>
	
	<xsl:template match="r:parameter[@name='verb' and (.='ListRecords'  or .='ListIdentifiers' )]">
			<!-- ListRecords and ListIdentifiers have:
				* EITHER a resumptionToken
				* OR a metadataPrefix, plus optional "set", "from" and "until" -->
			<xsl:choose>
				<xsl:when test="$parameters[@name='resumptionToken']">
				<!-- 
					<xsl:variable name="encoded-resumption-token">
						<xsl:call-template name="encode-for-uri">
							<xsl:with-param name="text" select="$parameters[@name='resumptionToken']"/>
						</xsl:call-template>
					</xsl:variable> -->
					<xsl:variable name="trove-next-page-link" select="substring-after($parameters[@name='resumptionToken'], '-')"/>
					<xsl:call-template name="transform-document">
						<xsl:with-param name="label">Trove URI for the next part of the list</xsl:with-param>
						<xsl:with-param name="document-uri" select="
							concat(
								$base-uri, 
								$trove-next-page-link, 
								'&amp;', $authentication
							)
						"/>		
					</xsl:call-template>		
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="date-range-query">
						<xsl:text>lastupdated:[</xsl:text>
						<xsl:choose>
							<xsl:when test="key('parameters', 'from')">
								<xsl:value-of select="key('parameters', 'from')"/>
							</xsl:when>
							<xsl:otherwise>*</xsl:otherwise>
						</xsl:choose>
						<xsl:text>+TO+</xsl:text>
						<xsl:choose>
							<xsl:when test="key('parameters', 'until')">
								<xsl:value-of select="key('parameters', 'until')"/>
							</xsl:when>
							<xsl:otherwise>*</xsl:otherwise>
						</xsl:choose>
						<xsl:text>]</xsl:text>						
					</xsl:variable>
					<xsl:variable name="search-query">
						<xsl:if test="starts-with($parameters[@name='set'], 'search:')">
							<!--
							<xsl:value-of select="substring-after($parameters[@name='set'], 'search:')"/>
							-->
							<xsl:call-template name="encode-for-uri">
								<xsl:with-param name="text" 
									select="substring-after($parameters[@name='set'], 'search:')"/>
							</xsl:call-template>
							<xsl:text>+</xsl:text>
						</xsl:if>
					</xsl:variable>
					<xsl:variable name="title-query">
						<xsl:if test="starts-with($parameters[@name='set'], 'title:')">
							<xsl:text>&amp;l-title=</xsl:text>
							<xsl:value-of select="substring-after($parameters[@name='set'], 'title:')"/>
						</xsl:if>
					</xsl:variable>
					<xsl:variable name="include-content-query">
						<xsl:if test="$verb='ListRecords'">include=articletext</xsl:if>
					</xsl:variable>
					<xsl:call-template name="transform-document">
						<xsl:with-param name="label">Trove URI for the start of a list of articles</xsl:with-param>
						<xsl:with-param name="document-uri" select="
							concat(
								$base-uri, 
								'/result?zone=newspaper&amp;reclevel=full&amp;n=',
								$page-size,
								'&amp;',
								$include-content-query,
								'&amp;q=',
								$search-query,
								$date-range-query,
								'&amp;',
								$authentication
							)
						"/>		
					</xsl:call-template>		
				</xsl:otherwise>
			</xsl:choose>
		</xsl:template>	
	<!-- generate an Identify statement -->
	<xsl:template match="r:parameter[@name='verb' and .='Identify']">
		<!-- we need to know the date of the oldest record in Trove to complete an Identify statement -->
		<xsl:call-template name="transform-document">
			<xsl:with-param name="label">Trove URI to find the earliest article</xsl:with-param>
			<xsl:with-param name="document-uri" select="
				concat(
					$base-uri, 
					'/result?zone=newspaper&amp;sortby=dateasc&amp;n=1&amp;q=lastupdated:[*+TO+*]&amp;',
					$authentication
				)
			"/>
		</xsl:call-template>
	</xsl:template>

	<!-- The OAI-PMH spec says metadata schemas must use XML namespaces. -->
	<xsl:template match="article" mode="trove-metadata-format">
		<article xmlns="http://api.trove.nla.gov.au/" >
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates mode="trove-metadata-format"/>
		</article>
	</xsl:template>
	
	<xsl:template match="*" mode="trove-metadata-format">
		<xsl:element name="{local-name(.)}" xmlns="http://api.trove.nla.gov.au/" >
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates mode="trove-metadata-format"/>
		</xsl:element>
	</xsl:template>
	
	<xsl:template match="articleText" mode="trove-metadata-format">
		<xsl:element name="{local-name(.)}" xmlns="http://api.trove.nla.gov.au/">
			<xsl:copy-of select="@*"/>
			<div xmlns="http://www.w3.org/1999/xhtml">
				<xsl:call-template name="unquote-html"/>
			</div>
		</xsl:element>
	</xsl:template>
	
	<xsl:template name="unquote-html">
		<xsl:param name="text" select="."/>	
		<xsl:variable name="safe-text">
			<xsl:call-template name="quote-unquoted-ampersands">
				<xsl:with-param name="text" select="$text"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:value-of select="$safe-text" disable-output-escaping="yes"/>
	</xsl:template>
	
	<xsl:template name="quote-unquoted-ampersands">
		<xsl:param name="text" />
		<xsl:param name="start-position" select="1"/>
		<xsl:choose>
			<xsl:when test="contains(substring($text, $start-position), '&amp;')">
				<xsl:variable name="prefix" select="substring-before(substring($text, $start-position), '&amp;')"/>
				<xsl:variable name="prefix-length" select="string-length($prefix)"/>
				<xsl:variable name="suffix-position" select="$start-position + $prefix-length + 1"/>
				<xsl:value-of select="$prefix"/>
				<xsl:choose>
					<xsl:when test="substring($text, $suffix-position, string-length('nbsp;')) = 'nbsp;' ">
						<!-- the ampersand prefixes the built-in html character entity name "nbsp" -->
						<xsl:text> </xsl:text>
						<xsl:call-template name="quote-unquoted-ampersands">
							<xsl:with-param name="text" select="$text"/>
							<xsl:with-param name="start-position" select="$suffix-position + string-length('nbsp;') "/>
						</xsl:call-template>
					</xsl:when>
					<xsl:when test="substring($text, $suffix-position, string-length('lt;')) = 'lt;' ">
						<!-- the ampersand prefixes the built-in xml character entity name "lt" -->
						<xsl:text>&amp;lt;</xsl:text>
						<xsl:call-template name="quote-unquoted-ampersands">
							<xsl:with-param name="text" select="$text"/>
							<xsl:with-param name="start-position" select="$suffix-position + string-length('lt;') "/>
						</xsl:call-template>
					</xsl:when>
					<xsl:otherwise>
						<!-- ampersand is a loner and needs to have the "amp" character entity name appended -->
						<xsl:text>&amp;amp;</xsl:text>
						<xsl:call-template name="quote-unquoted-ampersands">
							<xsl:with-param name="text" select="$text"/>
							<xsl:with-param name="start-position" select="$suffix-position"/>
						</xsl:call-template>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="substring($text, $start-position)"/>
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
