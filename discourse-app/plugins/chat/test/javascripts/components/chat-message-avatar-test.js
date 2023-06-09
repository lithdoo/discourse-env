import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import fabricators from "../helpers/fabricators";

module("Discourse Chat | Component | chat-message-avatar", function (hooks) {
  setupRenderingTest(hooks);

  test("chat_webhook_event", async function (assert) {
    this.message = ChatMessage.create(fabricators.chatChannel(), {
      chat_webhook_event: { emoji: ":heart:" },
    });

    await render(hbs`<ChatMessageAvatar @message={{this.message}} />`);

    assert.strictEqual(query(".chat-emoji-avatar .emoji").title, "heart");
  });

  test("user", async function (assert) {
    this.message = ChatMessage.create(fabricators.chatChannel(), {
      user: { username: "discobot" },
    });

    await render(hbs`<ChatMessageAvatar @message={{this.message}} />`);

    assert.true(exists('.chat-user-avatar [data-user-card="discobot"]'));
  });
});
