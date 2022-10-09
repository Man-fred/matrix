# mod_template
Template Repository for your custom Module

# Files included in this template:


## Fhem module files and folders

### FHEM/98_HELLO.pm

Hello world module. Included here for demonstration from FHEM Wiki

Look for development guideof a FHEM Module at the FHEM wiki
https://wiki.fhem.de/wiki/DevelopmentModuleIntro

Write your own module with your own filename


### lib/

Put any libs(pure perl modules) you provide in a own package (not main) create in here


## automated Testing



### t/FHEM/98_HELLO/*

Unittests for the fhem mdoule run via github actions if needed you have to write them into folder t/FHEM/<modulename>/


### t/FHEM/<packagename>/*

Unittests for the perl mdoule run via github actions if needed you have to write them into folder t/FHEM/<PACKAGENAME>/
Unittests (run prove on perl modules (testscripts)) needs to be enabled in the fhem_test.yml workflow

```
    - name: run prove on perl modules (testscripts)
      run: prove --exec 'perl -MDevel::Cover=-silent,1 -I FHEM ' -I FHEM -r -vv t/FHEM/<packagename>
```

### cpanfile

Cpan modules needed for running your module and your tests, they will be installed after perl is set up and running 

### .github/workflows/update.yml

This is a github action workflow which creates a controls file which is needed for fhem update command.
You are then able to install your new module 
`update all https://raw.githubusercontent.com/fhem/<reponame>/<branch>/controls_<reponame>.txt`

### .github/workflows/fhem_test.yml

This is a github action workflow which runs all your tests in t/xx_<Module> folder with different perl versions.

### .github/dependabot.yml

Dependabot will check if there are new versions form used actions you are using in your worflows and inform you.

### Code coverage
You can use codecov (https://about.codecov.io/)  to monitor your test code coveage.
Simply enable the coverage action an provide a token vom codecov.io via github secrets

    - uses: codecov/codecov-action@v1
      with:
        token: ${{ secrets.CODECOV_TOKEN }}
        file: ./cover_db/clover.xml
        flags: unittests,fhem,modules
        name: fhem (testscripts) ${{ matrix.perl }}

