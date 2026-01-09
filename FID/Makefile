.ONESHELL:
.PHONY: test check upload
test: check # 'test' is alias for 'check'
check:
	python3 -m pytest test/test_fid_fwhm.py


## handle uploading fwhm to flywheel only when needed
# take care not to reupload just because we did a fresh clone or pull
#
# expect .make/*.upload newer than *.lastup newer than fwhm.git
upload: .make/Prisma1QA.upload .make/Prisma2QA.upload .make/Prisma3QA.upload

.make/fwhm.git: fwhm.py | .make/
	GIT_TIME=$$(git diff --quiet HEAD -- fwhm.py && git log -1 --format="%ct" -- fwhm.py  || stat -c %Y fwhm.py)
	touch -d "@$$GIT_TIME" $@

# if git and/or mod is newer than last upload; reset lastup time (check again)
.make/%.lastup: .make/fwhm.git | .make/
	scanner=$(notdir $(basename $@ .lastup))
	REMOTE_TIME=$$(fw ls fw://mrrc/$$scanner/files/fwhm.py |& sed -En 's/^.*KB (.*) files.fwhm.py/\1/p')
	[ -z $$REMOTE_TIME ] && REMOTE_TIME=1970-01-01 # make very old if MIA
	touch -d "$$REMOTE_TIME" $@

# when either git or lastup have changed since upload: upload only if git is newer
.make/%.upload: .make/fwhm.git .make/%.lastup | .make/
	scanner=$(notdir $(basename $@ .upload))
	test .make/fwhm.git -nt .make/$$scanner.lastup && fw upload fwhm.py fw://mrrc/$$scanner && touch .make/$$scanner.lastup # so we dont have to check remote again
	touch $@

%/:
	mkdir -p $@
