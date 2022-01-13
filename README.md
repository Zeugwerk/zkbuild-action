# zkbuild-action

This [GitHub Action](https://github.com/features/actions) can be used to build and unittest PLCs that are contained in a Visual Studio Solution file (.sln) of your repository with a Zeugwerk CI/CD server. Use with an action such as [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action) to publish the results of the unittests to GitHub.

[Register](mailto:info@zeugwerk.at) to use this action for public repositories, this will allow you to run this action 30 times per month. [Contact us](mailto:info@zeugwerk.at) to retrieve a subscription if you need more builds per month or use Zeugwerk Doc for private repositories either on GitHub or any CI/CD server hosted in the cloud or on-premise or need support.



## Inputs

* `username`: Username of a Zeugwerk Useraccount (Required)

* `password`: Password of a Zeugwerk Useraccount (Required)

* `tcversion`: TwinCAT Version (i.e. TC3.1.4024.22) that should be used to compile and test the PLCs. The TwinCAT Version has to be available on a Zeugwerk CI/CD Server. If empty, the latest available version of TwinCAT is used. (Optional)

* `working-directory`: Path of the working directory, which should contain a Visual Studio solution and the configuration file `.Zeugwerk/config.json` (see Config section). (Optional)

## Build process

todo

## Unittests

todo

## Config

This action utilizes a config file, which should look like the example below, but has to be adapted for individual PLCs. *zkbuild* overwrites PLC settings with the information
that is taken from `config.json`. So when changing PLC properties, keep in mind to also adapt the configuration file. For instance, if new references are added to the PLC, also specify them in the configuration file, in the `system_references` section.

```json
{
  "name": "Twincat Project 1.sln",
  "repositories": [],
  "plcprojects": [
    {
      "name": "Untitled1",
      "version": "0.0.0.0",
      "type": "Application",
      "system_references": {
        "TC3.1.4024.22": [
          "Tc2_Standard=3.3.3.0",
          "Tc2_Utilities=3.3.47.0",
          "Tc2_EtherCAT=3.3.16.0"
        ]
      },
      "zframework": {},
      "bindings": {}
    }
  ]
}
```

* The initial parameter `name` sets the name of the (Visual Studio) solution that should be considered when building.
* `repositories` is a list of URLs where missing references (i.e. `system_references`) should be downloaded from. The CI/CD server doesn't necessarily have all PLC dependencies available and may need to download and install them first. As a fallback the CI/CD server tries to use the library that are already installed on the server.
  A repository is a URL that is publicly available and should have one of the following layouts
  1. Simple layout where all branches and Twincat versions use the same libraries
      ``` 
      root
      └── reference1_0.0.0.0.library
      └── reference2_0.0.0.0.library
      .
      .
      .
      ```  
  2. Advanced layout where branches and distinct twincat version may use a different set of libraries
     ```
      root
      ├── main                                  branch name
      │   └── TC3.1.4024.22                     used twincat version, see system_references
      |   │   └── reference1_0.0.0.0.library
      |   │   └── reference2_0.0.0.0.library
      ├── branch1                               branch name
      │   └── TC3.1.4024.20                     used twincat version, see system_references
      |   │   └── reference1_0.0.0.0.library
      |   │   └── reference2_0.0.0.0.library
      .
      .
      .
      ```


* What follows is the JSON dictionary `plcprojects` that describes how individual PLCs that are contained in the solution file should be handled
  * `name` has to match the PLC title as it is set in Visual Studio and TwinCAT XAE, respectively
  * `version` is the default version that is written to the PLC properties if no tags are available in the repository. If tags in the form x.y.z.w are available,
    the last tag is incremented and used instead (x.y.z.w+1)
  * `type` tells zkdoc if it should build the project as a "Library" or an "Application".
  * `system_references` is a JSON dictionary containing all the TwinCAT versions that are supported by the PLC and distinct library versions that are used for each distinct.
     This dictionary has the format `"<Twincat_Version>": ["Library1=<Library1_Versionnumber_or_*>", "Library2=<Library2_Versionnumber_or_*>"]`
  * **(tba)** `zframework`
  * **(tba)** `bindings`
TwinCAT version, using a wildcard for the latest available library on the target may be used instead of setting a version explicitly.


## Example usage

```yaml
name: Build/Test
on:
  push:
    branches:
      - main
      - 'release/**'
  pull_request:
    branches: [ main ]
  workflow_dispatch:
jobs:
  Build:
    name: Build/Test
    runs-on: ubuntu-latest
    steps:
      - name: Build
        uses: Zeugwerk/zkbuild-action@1.0.0
        with:
          username: ${{ secrets.API_USERNAME }}
          password: ${{ secrets.API_PASSWORD }}
      - name: Publish Unittest
        uses: EnricoMi/publish-unit-test-result-action@v1
        with:
          files: archive/test/TcUnit_xUnit_results.xml
```
