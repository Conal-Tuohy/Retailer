<!-- Well this was an interesting idea and would work in theory -->
<!-- In practice, transcluding the TEI into a ListRecords response exceeds implementation limits in jOAI at least -->
<!--  This harvest was not successful. Internal harvester error: java.lang.OutOfMemoryError: Java heap space -->
<!-- For simple crosswalks, though, this would totally work (e.g. gleaning RDF) -->

<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns:oai="http://www.openarchives.org/OAI/2.0/" 
xmlns:r="http://conaltuohy.com/ns/retailer/"
xmlns:marsden-tei="https://www.marsdenonline.otago.ac.nz/files/teischemaspecification.rng"
xmlns:tei="http://www.tei-c.org/ns/1.0"
xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
xmlns:dc="http://purl.org/dc/elements/1.1/"
exclude-result-prefixes="tei r marsden-tei"
>

	<xsl:output method="xml" indent="true"/>
	<xsl:variable name="upstream-base-uri">https://marsdenarchive.otago.ac.nz/oai2</xsl:variable>
	<xsl:variable name="parameters" select="/r:request/r:parameter"/>

	<xsl:template match="/r:request">
		<xsl:variable name="upstream-request-uri">
			<xsl:value-of select="$upstream-base-uri"/>
			<xsl:for-each select="$parameters">
				<xsl:choose>
					<xsl:when test="position() = 1">?</xsl:when>
					<xsl:otherwise>&amp;</xsl:otherwise>
				</xsl:choose>
				<xsl:choose>
					<xsl:when test="@name='metadataPrefix' and (.='tei' or .='marsden-tei')">metadataPrefix=oai_dc</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="concat(@name, '=', .)"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
		</xsl:variable>
		<xsl:variable name="upstream-response" select="document($upstream-request-uri)"/>
		<xsl:apply-templates mode="response" select="$upstream-response"/>
	</xsl:template>

	<xsl:template match="*|@* " mode="response">
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="response"/>
			<xsl:apply-templates mode="response"/>
		</xsl:copy>
	</xsl:template>
	
	<!-- ListMetadataFormats - add "tei" to the list -->
	<xsl:template match="oai:ListMetadataFormats" mode="response">
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="response"/>
			<xsl:apply-templates mode="response"/>
			<metadataFormat xmlns="http://www.openarchives.org/OAI/2.0/">
				<metadataPrefix>tei</metadataPrefix>
				<schema>http://www.tei-c.org/release/xml/tei/custom/schema/xsd/tei_all.xsds.xsd</schema>
				<metadataNamespace>http://www.tei-c.org/ns/1.0</metadataNamespace>
			</metadataFormat>
			<metadataFormat xmlns="http://www.openarchives.org/OAI/2.0/">
				<metadataPrefix>marsden-tei</metadataPrefix>
				<schema>https://www.marsdenonline.otago.ac.nz/files/teischemaspecification.rng</schema>
				<metadataNamespace>https://www.marsdenonline.otago.ac.nz/files/teischemaspecification.rng</metadataNamespace>
			</metadataFormat>		
		</xsl:copy>
	</xsl:template>
	
	<xsl:template match="oai:metadata" mode="response">
			<xsl:choose>
				<xsl:when test="$parameters[@name='metadataPrefix']='tei'">
					<xsl:copy>
						<xsl:variable name="resource-uri" select="
							concat(
								'http://marsdenarchive.otago.ac.nz/',
								oai_dc:dc/dc:identifier, 
								'/datastream/TEI/download'
							)
						"/>
						<xsl:variable name="tei" select="document($resource-uri)"/>
						<xsl:apply-templates mode="tei" select="$tei"/>
					</xsl:copy>
				</xsl:when>
				<xsl:when test="$parameters[@name='metadataPrefix']='marsden-tei'">
					<xsl:copy>
						<xsl:variable name="resource-uri" select="
							concat(
								'http://marsdenarchive.otago.ac.nz/',
								oai_dc:dc/dc:identifier, 
								'/datastream/TEI/download'
							)
						"/>
						<xsl:variable name="tei" select="document($resource-uri)"/>
						<xsl:copy-of select="$tei"/>
					</xsl:copy>
				</xsl:when>
				<xsl:otherwise>
					<xsl:copy-of select="."/>
				</xsl:otherwise>
			</xsl:choose>
	</xsl:template>
	
	<!-- Tidy up and convert Marsden's non-conformant TEI into TEI P5 -->
	
	<xsl:template mode="tei" match="marsden-tei:schemaSpec"/>
	
	<xsl:template mode="tei" match="marsden-tei:TEI.2">
		<tei:TEI>
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates mode="tei"/>
		</tei:TEI>
	</xsl:template>
	
	<xsl:template mode="tei" match="marsden-tei:*">
		<xsl:element name="tei:{local-name()}" namespace="http://www.tei-c.org/ns/1.0">
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates mode="tei"/>
		</xsl:element>
	</xsl:template>
	
</xsl:stylesheet>
