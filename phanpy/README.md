# Phanpy

Minimal stack for the static Phanpy frontend served by Nginx from
`ghcr.io/skobkin/phanpy-docker`.

## Setup

The image is already built with your Phanpy build-time configuration, so this
stack only needs port exposure. By default it uses
`ghcr.io/skobkin/phanpy-docker:latest`, and you can override that with
`IMAGE_REPOSITORY` and `IMAGE_TAG`.
