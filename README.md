# zkbuild-action

This [GitHub Action](https://github.com/features/actions) can be used to build and unittest PLCs that are contained in a Visual Studio Solution file (.sln) of your repository with a Zeugwerk CI/CD server. Use with an action such as [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action) to publish the results of the unittests to GitHub.

[Register](mailto:info@zeugwerk.at) to use this action for public repositories, this will allow you to run this action 30 times per month. [Contact us](mailto:info@zeugwerk.at) to retrieve a subscription if you need more builds per month, use zkbuild for private repositories (also on other platforms than GitHub) or need support.



## Inputs

* `username`: Username of a Zeugwerk Useraccount (Required)

* `password`: Password of a Zeugwerk Useraccount (Required)

* `tcversion`: (Optional) This defaults to TC3.1 and should usually not be changed without contacting us. The setting can be used to overwrite the TwinCAT target that the PLC is compiled for



### Creating secrets

We highly recommend to store the value for `username` and `password` in GitHub as secrets. GitHub Secrets are encrypted and allow you to store sensitive information, such as access tokens, in your repository. Do these steps for `username` and `password`

1. On GitHub, navigate to the main page of the repository.
2. Under your repository name, click on the "Settings" tab.
3. In the left sidebar, click Secrets.
4. On the right bar, click on "Add a new secret" 
5. Type a name for your secret in the "Name" input box. (i.e. `ACTIONS_ZGWK_USERNAME`, `ACTIONS_ZGWK_PASSWORD`)
6. Type the value for your secret.
7. Click Add secret. 

## Config

This action requires a configuration file that is places in the folder `.Zeugwerk/config.json`. The simplest way to generate a configuration file is by using the [Twinpack Package Manager](https://github.com/Zeugwerk/Twinpack/blob/main/README.md#configuration-file-zeugwerkconfigjson).

A typcial configuration file for a solution with 1 PLC looks like this (Twinpack generates this for you automatically)

```json
{
  "fileversion": 1,
  "solution": "TwinCAT Project1.sln",
  "projects": [
    {
      "name": "TwinCAT Project1",
      "plcs": [
        {
          "version": "1.0.0.0",
          "name": "Untitled1",
          "type": "Library",
          "packages": [
            {
              "version": "1.2.19.0",
              "repository": "bot",
              "name": "ZCore",
              "branch": "release/1.2",
              "target": "TC3.1",
              "configuration": "Distribution",
              "distributor-name": "Zeugwerk GmbH"
            }
          ],
          "references": {
            "*": [
              "Tc2_Standard=*",
              "Tc2_System=*",
              "Tc3_Module=*"
            ]
          }
        }
      ]
    }
  ]
}
```

## Unittests

zkbuild can also execute unittests. We support two variants how this can be achieved

### Unittests defined in own PLC

- For this, it is mandatory to place your unittest solution in a subfolder called `tests`
- It **requires the usage** of the latest release of [TcUnit](https://github.com/tcunit/TcUnit).
- Tests can be implemented as documented in TcUnit.
- A seperate configuration file is needed in `tests\.Zeugwerk\config.json`, which describes how to build the unittest PLC

### Unittests defined directly in the PLC

- This is the perferred way for us to implement tests, because it puts the tests right next to the actual code.
- It **requires the usage** of the package `Zeugwerk.Core` (`ZCore`), because zkbuild relies on an [assertions interface](https://doc.zeugwerk.dev/reference/ZCore/UnitTest/IAssertions.html) that is defined in this library.
- Creating tests is pretty straight forward: If you want to write testsuite for the function block `Valve`, implement the following function block
- zkbuild automatically removes all function blocks that implement `ZCore.IUnittest` from the .library file that is returned by the action

```
FUNCTION_BLOCK ValveTest EXTENDS Valve IMPLEMENTS ZCore.IUnittest

METHOD Test_NameOfTest1
VAR_INPUT
  assertions : ZCore.IAssertions;
END_VAR

assertions.IsTrue(TRUE, 'This test passes');

METHOD Test_NameOfTest2
VAR_INPUT
  assertions : ZCore.IAssertions;
END_VAR

assertions.EqualsDint(5, 4, 'This test failes');
```

It is important that the function block implements the interface `ZCore.IUnittest`, then every method with the signature above is regarded as a test.
You can implement as many testsuites and tests as you want. The [assertions interface](https://doc.zeugwerk.dev/reference/ZCore/UnitTest/IAssertions.html) offers a lot of methods to write tests. Extending from the function block that is tested allows to manipulate private variables of your test object.

## Publishing a library

When the action is successfully finished and the configuration is set to `type = Library`, there will be a library placed in the working directory of the GitHub running in the path `archive/REPO_NAME/TC3.1/PLCNAME_VERSION.library`.
This library can then we uploaded to the Twinpack Package Manager via a seperate [publish action](https://github.com/Zeugwerk/twinpack-action). Of course it is also possible to process the library further in any other way (creating a GitHub Release, pushing it to a private server, ...)

## Example usage

```yaml
name: Build/Test
on:
  push:
    branches:
      - main
      - 'release/**'
  pull_request_target:
  workflow_dispatch:
jobs:
  Build:
    name: Build/Test
    runs-on: ubuntu-latest
    steps:
      - name: Build
        uses: Zeugwerk/zkbuild-action@1.0.0
        with:
          username: ${{ secrets.ACTIONS_ZGWK_USERNAME }}
          password: ${{ secrets.ACTIONS_ZGWK_PASSWORD }}
      - name: Upload Artifact
        uses: actions/upload-artifact@v3
        with:
          name: artifact
          path: |
            **/*library 
      - name: Publish Unittest
        uses: EnricoMi/publish-unit-test-result-action@v1
        with:
          files: archive/test/TcUnit_xUnit_results.xml
```

## Patches

Zeugwerk CI supports to apply patches to the source code of the repository, which are applied before compiling the code.
At the moment the following types of patches are supported
- `Platform patches`: are applied for specific TwinCAT Versions
- `Argument patches`: can be used for feature flags. At the moment this feature is not enabled for the free-to-use zkbuild, if you are interested in using it for your open source project, you may submit an [issue](https://github.com/Zeugwerk/zkbuild-action/issues).
  
To use patches, a `config.json` file has to be used and patches have to be configured in the configuration file as follows

```jsonc
{
  "fileversion": 1,
  "solution": "TwinCAT Project1.sln",
  "projects": [
    {
      "name": "TwinCAT Project1",
      "plcs": [
        {
          ...
          "name": "Untitled1",
          "patches":
            "platform": {
              "TC3.1.4024.56": [
                "git-patch-for-specific-twincat-version.patch",
                "search-and-replace.for-specific-twincat-version.replacement"
              ]
            },
            "argument": {
              "": [
                "git-patch.patch",
                "search-and-replace.replacement"
              ]
            },
          ...
        }
      ]
    }
  ]
}
```

### Git patches
Any file with the extension `.patch` is [applied as a Git patch](https://git-scm.com/docs/git-apply). You can use `git diff > some-changes.patch` to create the patch and the CI system, will use `git apply -3 some-changes.patch` to apply the patch. If the patch can not be applied correctly, the pipeline will go to failure.

### Search-and-replace patch
We support a mechanismn to do search-and-replace over many files in the source code before it is compiled. This is simpler than using a proper git patch. A replacement patch is a json file, which has the following format and has the file extension `.replacement`

```jsonc
{
  "filter": "*.TcPOU",
  "search": "pattern",
  "replace": "replacement"
}
```

- `filter` can be used to filter for specific files, the examples filters for all POUs in the source code
- `search` is a the regular expression pattern to match, special characters have to be escaped
- `replace` is the replacement string, which may contain identifiers to refer to captures of the regex (`$1` ... `$N`). It is also possible to use enviornment variables here. Zeugwerk CI uses Jenkins, enviornment variables can be referred to with `{{env.ENVIORNMENT_VARIABLE}}`. See [here](https://devopsqa.wordpress.com/2019/11/19/list-of-available-jenkins-environment-variables/) for a list of possible enviornmemt variables.
