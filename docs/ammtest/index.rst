AMM testing library
===================

AMM provides a simple library for running unit tests.


Quickstart
----------

To begin, create a directory named ``_test`` in your package. In it, create lua files
that use `ammtest` library do declare testing suites.

Create a suite using `ammtest.suite`:

.. code-block:: lua

   test = require "ammtest"

   suite = test.suite()

Within suite, create tests using `ammcore.Suite.case`, and use assert functions
in them:

.. code-block:: lua

   suite:case("test addition", function ()
       test.assertEq(2 + 2, 4)
   end)

You can create parametrized tests by using `ammcore.Suite.caseParams`
and `ammcore.param`:

.. code-block:: lua

   suite:caseParams(
       "test addition",
       {
           test.param(2, 2, 4),
           test.param(5, 10, 15),
       },
       function (a, b, expected)
          test.assertEq(a + b, expected)
       end
   )

The above test will run several times, one for each parameter; test results will
be reported separately.

Finally, run all tests by starting a computer with ``ammtest.bin.main`` program.


Capturing computer log
----------------------

When AMM runs tests, everything that you print (including calls to `print`
and `computer.log`) gets captured and reported in case of test failure.

You can get the captured output using `ammtest.getLog` and `ammtest.getLogStr`.
This is useful is you need to assert that certain information was printed
to the console.


Set up and tear down handlers
-----------------------------

You can specify what happens before beginning and after end of every test and suite.
For this, override `~ammtest.Suite.setupTest`, `~ammtest.Suite.teardownTest`,
`~ammtest.Suite.setupSuite`, and `~ammtest.Suite.teardownSuite` of the test suite.


Further reading
---------------

.. toctree::
   :maxdepth: 1

   API reference <api/index.rst>
