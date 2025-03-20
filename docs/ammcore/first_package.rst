Creating your first AMM package
===============================

Now that you have your coding environment set up, it's time to write some code.

First, let's decide how to name a package.

.. tab-set::

   .. tab-item:: I plan to share my package with others

      To do so, you'll need to upload your package to `GitHub`_, meaning that you'll
      need a GitHub username.

      You'll also need a repository name; that is, name of a GitHub project
      that you will create to upload your code. Repository name should not include
      dashes in it.

      With all of the above, your package name will consist of your GitHub name,
      repository name, and an optional sub-package name (if you plan to store
      multiple packages in a single repository).

      For example, my GitHub username is ``taminomara``, my repository with code
      for Fics-It Networks is called ``amm``, and I want to create a sub-package
      named ``example``. Therefore, I'll use the name

      .. code-block:: text

         taminomara-amm-example

      Repository name and sub-package name should form valid Lua identifiers. That is,
      they should consist of letters, numbers and underscores, and they can't start
      with numbers.

      .. warning::

         If your GitHub username has dashes in it, you *have* to use sub-package
         names to avoid ambiguity.

         That is, if your GitHub name is ``example-name``, and you create a package
         named ``example-name-thing``, it is impossible to guess whether
         it is a package in repository ``example-name/thing``, or it is a sub-package
         ``thing`` in repository ``example/name``.

         Thus, you need to use sub-packages, like this: ``example-name-repo-thing``.
         Here, ``repo`` is the name of a repository, and ``thing`` is the name
         of a sub-package.

   .. tab-item:: This package is only for myself

      You can use any name that forms a valid Lua identifier. That is,
      your package name should consist of letters, numbers and underscores,
      and it can't start with a number.

.. _GitHub: https://github.com

For this example, we'll go with name ``taminomara-amm-example``.

In the root of the hard drive, create a directory for the package (named same as the package).
In this example it's ``taminomara-amm-example/``.

Inside, create a file called ``.ammpackage.json`` with the following content
(replace package name and version with your own):

.. code-block:: json

   {
     "name": "taminomara-amm-example",
     "version": "0.0.0",
     "requirements": {
       "taminomara-amm-amm": "~0.1"
     },
     "devRequirements": {
       "taminomara-amm-ammtest": "~0.1"
     }
   }
