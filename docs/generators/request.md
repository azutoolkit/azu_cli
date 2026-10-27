---
description: Generate Azu::Request contracts per action, with the validations for create and update and the id for show, edit and destroy.
---

# Request

`azu g request` writes one `Azu::Request` struct per action, under `src/requests/<plural>/`. Create and update carry the resource's attributes. Show, edit and destroy carry the `id` from the route. Index and new carry nothing. The request is where input gets validated, so the endpoint and the service can trust what they receive.

## Overview & visual demo

<figure><img src="../assets/terminal-ui/11-generate-preview.png" alt="azu generate preview listing the request files for comments: create_request, destroy_request, edit_request, index_request, new_request, show_request and update_request"><figcaption><p>The scaffold's preview lists one request file per action. A single <code>azu g request</code> writes just the one you name.</p></figcaption></figure>

```mermaid
flowchart LR
  A["Form or JSON params"] --> B["Posts::CreateRequest"]
  B --> C["Posts::CreateEndpoint gets a validated request"]
  C --> D["Posts::CreateService"]
  D --> E["Post saved"]
```

## Quickstart & command syntax

```bash
azu g request post create title:string body:text
azu g request post update title:string body:text
azu g request post show
```

{% tabs %}
{% tab title="Create" %}
```bash
azu g request post create title:string body:text   # strings are required
```
{% endtab %}

{% tab title="Update" %}
```bash
azu g request post update title:string body:text   # every field optional, a sent value can't be blank
```
{% endtab %}

{% tab title="Show" %}
```bash
azu g request post show                            # carries the id only
```
{% endtab %}
{% endtabs %}

| Part           | Meaning                                                                       | Default              |
| -------------- | ----------------------------------------------------------------------------- | -------------------- |
| `name`         | Singular or plural resource name                                              | required             |
| `action`       | One of `index show new create edit update destroy`                            | `index`              |
| `attributes`   | `name:type[?][:modifier]`. Used by `create` and `update`; ignored otherwise   | none                 |
| `--force`      | Overwrite existing files without asking                                       | off                  |
| `--dry-run`    | List files and diffs, write nothing                                           | off                  |
| `--check`      | Type-check with the new file; write nothing if it doesn't compile            | off                  |
| `--yes`        | Write without asking (the plan is still printed on a terminal)                | off                  |

The attribute types and modifiers are the same as for the model. See [model](model.md).

## Realistic output

{% code title="generated files" %}
```text
src/requests/posts/create_request.cr
src/requests/posts/update_request.cr
src/requests/posts/show_request.cr
src/requests/predicates.cr        (written with update: defines the given? predicate)
```
{% endcode %}

{% code title="src/requests/posts/create_request.cr" %}
```crystal
module Blog
  struct Posts::CreateRequest
    include Azu::Request

    getter title : String
    getter body : String

    validate title, presence: true
    validate body, presence: true
  end
end
```
{% endcode %}

*On create, every string is required. The generator adds `presence` for strings only.*

{% code title="src/requests/posts/update_request.cr" %}
```crystal
module Blog
  struct Posts::UpdateRequest
    include Azu::Request

    getter title : String?
    getter body : String?

    validate title, given: true
    validate body, given: true
  end
end
```
{% endcode %}

*On update, each field is optional (PATCH). A value that is sent must not be blank.*

{% code title="src/requests/posts/show_request.cr" %}
```crystal
module Blog
  struct Posts::ShowRequest
    include Azu::Request

    getter id : Int64
  end
end
```
{% endcode %}

*The id comes from the route. Show, edit and destroy carry it.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** `azu routes` shows each endpoint's request type next to its response, so you can see which request an action uses.
{% endhint %}

{% hint style="success" %}
Give the request, the model and the service the same attributes. The service reads `request.<field>` for each attribute, so a field the request lacks fails to compile.
{% endhint %}

{% hint style="warning" %}
The generator adds a `validate` line for strings only. Numbers, booleans and times get no rule from it. Add the rules you need by hand.
{% endhint %}

{% hint style="warning" %}
A boolean on create defaults to `false`, so the request always has a value. On update it is `Bool?`, and an unsent field leaves the record unchanged.
{% endhint %}

{% hint style="danger" %}
Don't reuse one request for create and update. Create requires the strings and update makes them optional, so keep them as two contracts.
{% endhint %}
