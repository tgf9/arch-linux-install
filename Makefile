plant := bin/plant
tmpls = $(shell find tmpls -name "*.tmpl")

dell-xps-13-9310-0991/README.md: dell-xps-13-9310-0991/root.tmpl $(tmpls)
	$(plant) -tmpls ./tmpls -root $< > $@

.PHONY: save
save: dell-xps-13-9310-0991/README.md
	git add --all
	git commit -m "Save"
	git push origin main
