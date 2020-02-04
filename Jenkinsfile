elifePipeline {
    def commit
    def commitShort
    def schemaVersion
    def tag
    DockerImage image

    node('containers-jenkins-plugin') {
        stage 'Checkout', {
            checkout scm
            commit = elifeGitRevision()
            commitShort = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
            schemaVersion = params.'SCHEMA_VERSION' ?: "master"
            tag = "${commitShort}-${schemaVersion}"
        }

        stage 'Build', {
            sh "docker-wait-daemon"
            def imageName = "elifesciences/basex-validator"
            def dockerfile = 'Dockerfile'
            sh "docker build --pull -f ${dockerfile} -t ${imageName}:${tag} . --build-arg schema_version=${schemaVersion}"
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