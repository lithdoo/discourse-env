import { module, test } from "qunit";

import { hbs } from "ember-cli-htmlbars";
import { render } from "@ember/test-helpers";

import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

function containsExactly(assert, expectation, actual, message) {
  assert.deepEqual(
    Array.from(expectation).sort(),
    Array.from(actual).sort(),
    message
  );
}

module("Integration | Component | sidebar | section-link", function (hooks) {
  setupRenderingTest(hooks);

  test("default class attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="test" @route="discovery.latest" />`;

    await render(template);

    containsExactly(
      assert,
      query("a").classList,
      [
        "ember-view",
        "sidebar-row",
        "sidebar-section-link",
        "sidebar-section-link-test",
      ],
      "has the right class attribute for the link"
    );
  });

  test("custom class attribute for link", async function (assert) {
    const template = hbs`<Sidebar::SectionLink @linkName="test" @route="discovery.latest" @class="123 abc" />`;

    await render(template);

    containsExactly(
      assert,
      query("a").classList,
      [
        "123",
        "abc",
        "ember-view",
        "sidebar-row",
        "sidebar-section-link",
        "sidebar-section-link-test",
      ],
      "has the right class attribute for the link"
    );
  });
});
