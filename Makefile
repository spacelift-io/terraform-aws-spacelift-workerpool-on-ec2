.PHONY: docs

docs: README.md
	docker run --rm --volume "$$(pwd):/terraform-docs" -u $$(id -u) quay.io/terraform-docs/terraform-docs:0.20.0 markdown /terraform-docs
