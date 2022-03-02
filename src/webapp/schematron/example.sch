<schema
    xmlns="http://purl.oclc.org/dsdl/schematron"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:java="http://www.java.com/"
    xmlns:file="java.io.File"
    xmlns:ali="http://www.niso.org/schemas/ali/1.0/"
    xmlns:mml="http://www.w3.org/1998/Math/MathML"
    queryBinding="xslt2">
    
    <title>Example Schematron</title>
    
    <pattern>
        
        <rule id="example-checks" context="p">
            
            <assert test="italic"
                role="error"
                see="https://www.schematron.com/"
                id="example-check">Every p element must contain an italic element. This one does not.</assert>
            
        </rule>
    </pattern>
    
</schema>