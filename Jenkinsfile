elifePipeline {
    def tag
    def schemaVersion
    DockerImage image

    node('containers-jenkins-plugin') {
        stage 'Checkout', {
            checkout scm
            def commit = elifeGitRevision()
            def commitShort = commit.substring(0, 8)
            schemaVersion = params.schemaVersion ?: 'master'
            tag = "${commitShort}-${schemaVersion}"
        }

        stage 'Build', {
            dockerBuild('basex-validator', tag, null, 'elifesciences', ['schema_version': schemaVersion])
        }

    //    stage 'Tests', {
    //         dockerComposeProjectTests('digests', commit, ['/srv/digests/build/*.xml'])
    //         dockerComposeSmokeTests(commit, [
    //             'scripts': [
    //                 'wsgi': './smoke_tests_wsgi.sh',
    //             ],
    //         ])
    //    }

        elifeMainlineOnly {
            stage 'Publish', {
                image = DockerImage.elifesciences(this, 'basex-validator', tag)
                image.push()
                image.tag('latest').push()
            }
        }
    }
}