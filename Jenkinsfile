elifePipeline {
    def branch
    def commitShort
    def timestamp
    DockerImage image

    node('containers-jenkins-plugin') {
        elifeMainlineOnly {
            stage 'Checkout', {
                checkout scm
                branch = ${GIT_BRANCH}
                commitShort = elifeGitRevision().substring(0, 8)
                timestamp = sh(script: 'date --utc +%Y%m%d.%H%M', returnStdout: true).trim()
            }

            stage 'Build', {
                dockerBuild('basex-validator', 'latest', null, 'elifesciences', ['schema_version': schemaVersion])
            }

            stage 'Smoke Tests', {
                agent {
                    docker { image 'elifesciences/basex-validator:ci' }
                }
                sh "sleep 10"
                sh "cd tests && ./smoke_tests_wsgi.sh && cd .."
            }

            stage 'Publish', {
                image = DockerImage.elifesciences(this, 'basex-validator', tag)
                image.push()
                image.tag("${branch}-${commitShort}-${timestamp}").push()
                image.tag("${branch}-${commitShort}").push()
            }
        }
    }
}