docs:
	docker run --rm --volume "$(CURDIR):/terraform-docs" quay.io/terraform-docs/terraform-docs:0.19.0 markdown /terraform-docs --indent 2 --output-file README.md