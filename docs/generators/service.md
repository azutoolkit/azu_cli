---
description: Generate service classes for create, update and destroy, which save or delete the record a validated request describes.
---

# Service

`azu g service` writes one class per write action under `src/services/<plural>/`. A service takes the validated request, saves or deletes the record, and returns it. It doesn't validate: the request already did that.

## Overview & visual demo

Generate a service for application behavior that spans an endpoint or model. Keep dependencies explicit so the service remains straightforward to test and reuse.

<figure><img src="../assets/terminal-ui/12-generate-written.png" alt="azu generate after writing, listing the comment services create_service, destroy_service and update_service with their line counts"><figcaption><p>After Enter, the service files are listed with their line counts. Each action is its own file.</p></figcaption></figure>

```mermaid
flowchart LR
  A["Posts::CreateEndpoint"] --> B["Posts::CreateRequest, already validated"]
  B --> C["Posts::CreateService#call"]
  C --> D["Post.new, then save!"]
  D --> E["returns the Post"]
```

## Quickstart & command syntax

```bash
azu g service post create update destroy title:string body:text
azu g service post create title:string body:text
azu g service post title:string body:text
```

{% tabs %}
{% tab title="Create only" %}
```bash
azu g service post create title:string body:text
```
{% endtab %}

{% tab title="Destroy" %}
```bash
azu g service post destroy                   # no attributes needed
```
{% endtab %}

{% tab title="Dry run" %}
```bash
azu g service post create update title:string body:text --dry-run
```
{% endtab %}
{% endtabs %}

| Part           | Meaning                                                                          | Default                     |
| -------------- | -------------------------------------------------------------------------------- | --------------------------- |
| `name`         | Singular or plural resource name                                                 | required                    |
| `actions`      | Any of `create update destroy`                                                   | all three                   |
| `attributes`   | `name:type[?][:modifier]`, the same list as the request. Used by create and update | none                     |
| `--force`      | Overwrite existing files without asking                                          | off                         |
| `--dry-run`    | List files and diffs, write nothing                                              | off                         |
| `--check`      | Type-check with the new files; write nothing if it doesn't compile               | off                         |
| `--yes`        | Write without asking (the plan is still printed on a terminal)                   | off                         |

## Realistic output

{% code title="generated files" %}
```text
src/services/posts/create_service.cr
src/services/posts/update_service.cr
src/services/posts/destroy_service.cr
```
{% endcode %}

{% code title="src/services/posts/create_service.cr" %}
```crystal
module Blog
  class Posts::CreateService
    def call(request : Posts::CreateRequest) : Post
      record = Post.new(title: request.title, body: request.body)
      record.save!
      record
    end
  end
end
```
{% endcode %}

*Create builds the record from the request's fields and saves it. Each attribute you pass becomes one `request.<field>` here.*

{% code title="src/services/posts/update_service.cr" %}
```crystal
module Blog
  class Posts::UpdateService
    def call(record : Post, request : Posts::UpdateRequest) : Post
      request.title.try { |value| record.title = value }
      request.body.try { |value| record.body = value }
      record.save!
      record
    end
  end
end
```
{% endcode %}

*Update changes only the fields the request carried. A field that wasn't sent stays as it was.*

{% code title="src/services/posts/destroy_service.cr" %}
```crystal
module Blog
  class Posts::DestroyService
    def call(record : Post) : Bool
      record.delete!
    end
  end
end
```
{% endcode %}

*Destroy takes the record the endpoint found, so it has no request.*

## Do's and don'ts

{% hint style="info" %}
A service is a plain class. Call it from an endpoint, a job or a console, the same way the generated endpoints do.
{% endhint %}

{% hint style="success" %}
Pass the same attributes to the service as to the request. The generated code reads `request.<field>` for each one, so a mismatch fails at compile time instead of at runtime.
{% endhint %}

{% hint style="warning" %}
`save!` and `delete!` raise when they fail. The generated endpoints don't rescue that, so a failed save reaches azu's error handling as an exception.
{% endhint %}

{% hint style="danger" %}
Don't call a service with a request you built by hand from `params`. Skipping the request skips its validation, and the service trusts what it gets.
{% endhint %}
