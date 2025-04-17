Quickstart
==========

AmmGui is inspired by React JS library. To make an interface, you describe
its structure using functions from `ammgui.dom`, style it with functions
from `ammgui.css`, then hand it off to the runtime to display.

.. tip::

   If you're a React user, this terminology might be familiar:

   - `ammgui.dom` is like React's shadow DOM: it's a lightweight representation
     of an interface's structure;
   - `ammgui.component` is a combination of React's component and HTML
     tag implementation. In other GUI frameworks they are better known
     as widgets.

.. code-block:: lua

   local gui = require "ammgui"
   local dom = require "ammgui.dom"

   local app = gui.App:New(function() {
       return dom.div {
           dom.h1 {
               "Hello, world!"
           },
           dom.p {
               "We're just showing some basics, "
               "like headings and paragraphs!"
           }
       }
   })

   app:run()


Quick DOM overview
------------------

`ammgui.dom` implements functions that are similar to HTML tags. Their functionality,
however, is significantly simpler.

- Text elements: `ammgui.dom.span`, `ammgui.dom.em`, `ammgui.dom.code`.

  Text elements can't be nested, and you can't mix text and block elements.
  That is, text elements can only appear inside of `~ammgui.dom.p`, `~ammgui.dom.h1`,
  `~ammgui.dom.h2`, and `~ammgui.dom.h3`.

- Block elements:

  - `ammgui.dom.div` works like a standard HTML div with ``display: block``.
    You can configure its padding, border (we call it ``outline``, and so on).

    AmmGui doesn't support margins, but you can use `~ammgui.css.rule.BlockProperties.gap`
    to separate elements inside the div.

  - `ammgui.dom.p`, `ammgui.dom.h1`, `ammgui.dom.h2`, and `ammgui.dom.h3` are block
    elements that contain text.

  - `ammgui.dom.flex` works like HTML div with ``display: flex``. We decided
    to separate div and flex to keep implementation simpler.
