elifePipeline {
    def branch
    def commitShort
    def timestamp
    DockerImage image

    node('containers-jenkins-plugin') {
        elifeMainlineOnly {
            stage 'Checkout', {
                checkout scm
                branch = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                commitShort = elifeGitRevision().substring(0, 8)
                timestamp = sh(script: 'date --utc +%Y%m%d.%H%M', returnStdout: true).trim()
            }

            stage 'Build', {
                dockerBuild('basex-validator', 'latest', null, 'elifesciences')
            }

            stage 'Smoke Tests', {
                try {
                    sh "docker run -d --name 'basex-validator' --rm --memory='512m' -p 1984:1984 -p 8984:8984 elifesciences/basex-validator:latest"
                    sh "sleep 10"
                    sh "cd test && ./smoke_tests_wsgi.sh && cd .."
                } finally {
                    sh "docker stop 'basex-validator'"
                }
            }

            stage 'Publish to Dockerhub', {
               image = DockerImage.elifesciences(this, 'basex-validator', 'latest')
               image.push()
               image.tag("${branch}-${commitShort}-${timestamp}").push()
               image.tag("${branch}-${commitShort}").push()
            }
        }
    }
}