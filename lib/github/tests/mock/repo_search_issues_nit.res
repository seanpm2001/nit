{"total_count":151,"incomplete_results":false,"items":[{"url":"https://api.github.com/repos/nitlang/nit/issues/2747","repository_url":"https://api.github.com/repos/nitlang/nit","labels_url":"https://api.github.com/repos/nitlang/nit/issues/2747/labels{/name}","comments_url":"https://api.github.com/repos/nitlang/nit/issues/2747/comments","events_url":"https://api.github.com/repos/nitlang/nit/issues/2747/events","html_url":"https://github.com/nitlang/nit/pull/2747","id":444577497,"node_id":"MDExOlB1bGxSZXF1ZXN0Mjc5MjA5MjEx","number":2747,"title":"Introduction of contracts in Nit","user":{"login":"Delja","id":26239416,"node_id":"MDQ6VXNlcjI2MjM5NDE2","avatar_url":"https://avatars1.githubusercontent.com/u/26239416?v=4","gravatar_id":"","url":"https://api.github.com/users/Delja","html_url":"https://github.com/Delja","followers_url":"https://api.github.com/users/Delja/followers","following_url":"https://api.github.com/users/Delja/following{/other_user}","gists_url":"https://api.github.com/users/Delja/gists{/gist_id}","starred_url":"https://api.github.com/users/Delja/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/Delja/subscriptions","organizations_url":"https://api.github.com/users/Delja/orgs","repos_url":"https://api.github.com/users/Delja/repos","events_url":"https://api.github.com/users/Delja/events{/privacy}","received_events_url":"https://api.github.com/users/Delja/received_events","type":"User","site_admin":false},"labels":[{"id":1252784180,"node_id":"MDU6TGFiZWwxMjUyNzg0MTgw","url":"https://api.github.com/repos/nitlang/nit/labels/ok_to_test","name":"ok_to_test","color":"1e179e","default":false}],"state":"open","locked":false,"assignee":null,"assignees":[],"milestone":null,"comments":0,"created_at":"2019-05-15T18:16:56Z","updated_at":"2019-06-17T15:08:13Z","closed_at":null,"author_association":"CONTRIBUTOR","pull_request":{"url":"https://api.github.com/repos/nitlang/nit/pulls/2747","html_url":"https://github.com/nitlang/nit/pull/2747","diff_url":"https://github.com/nitlang/nit/pull/2747.diff","patch_url":"https://github.com/nitlang/nit/pull/2747.patch"},"body":"# Contract\r\n\r\nAdding contract programming (Design by contract) in Nit language. Contracts works with nit annotations.\r\n\r\n## Annotations\r\n\r\nTo define a new contract you need to use the corresponding annotation. For example it is possible to define a contract that x must be strictly greater than 5. To do it would be necessary to define the contract in the following way `expects (x > 5)`. All expressions returning a boolean (comparison...) can be used as a condition.\r\n\r\nTwo annotations were added:\r\n\t\r\n- `expects` to indicate the conditions need to the execution of the methods\r\n- `ensures` to indicate the conditions of guarantee at the end of the execution of the methods\r\n\r\n## Method contract (ensures, expects)\r\n\r\nFor each method it is possible to define preconditions (`expects`) and  post-conditions (`ensures`). If the call of the method satisfies the prerequisites of the method, the caller may assume that the return conditions will be satisfied.\r\n\r\nThe method contracts can access all the parameters of the method as well as the set of attributes/methods visible in the context of the method. i.e the set of parameters and the set of methods and attributes of the current class can be used (attributes declare locally in the method can not be used). For post-conditions (ensures) the `result` attribute has been added to perform a check on the return value of the method.\r\n\r\n## Process\r\n\r\nA phase is executed to check all the methods. This check is done to know if:\r\n\r\n- The method is annoted (redefined or not)\r\n\r\n- The method is a redefinition of a method already having a contract (i.e a method that does not add any new conditions to the existing contract).\r\n\r\nWhen a contract is detected the code it's `extended` to add the verification features. A method is created to check the conditions of the contract.\r\n\r\n### Exemple\r\n\r\n#### Expect:\r\n```\r\nclass MyClass\r\n\tfun foo(x: Int)\r\n\tis\r\n\t\texpects(x > 0)\r\n\tdo\r\n\t\t[...]\r\n\tend\r\nend\r\n```\r\nRepresentation of the compiled class\r\n```\r\nclass MyClass\r\n\tfun foo(x: Int)\r\n\tis\r\n\t\texpects(x > 0)\r\n\tdo\r\n\t\tfoo_expects(x)\r\n\t\t[...]\r\n\tend\r\n\t\r\n\tfun foo_expects(x: Int)\r\n\tdo\r\n\t\tassert x > 0\r\n\tend\r\nend\r\n```\r\n#### Ensure:\r\n```\r\nclass MyClass\r\n\tfun foo(x: Int): Bool\r\n\tis\r\n\t\tensures(result == true)\r\n\tdo\r\n\t\t[...]\r\n\t\treturn true\r\n\tend\r\nend\r\n```\r\nRepresentation of the compiled class\r\n\r\n```\r\nclass MyClass\r\n\tfun foo(x: Int): Bool\r\n\tis\r\n\t\tensures(result == true)\r\n\tdo\r\n\t\t[...]\r\n\t\tvar result = true\r\n\t\tfoo_ensures(x, result)\r\n\t\treturn result\r\n\tend\r\n\t\r\n\tfun foo_ensures(x: Int, result: Bool)\r\n\tdo\r\n\t\tassert result == true\r\n\tend\r\nend\r\n```\r\n\r\n## Inheritance\r\n\r\nContracts support redefinition and adding condition. Noted that when a contract is defines in a parent class, it is no longer possible to remove this contract on all the classes that inherit or redefine them. They only need to be increased according to different subtyping rules.\r\n\r\nAll preconditions (expects) can be weakened. i.e it is possible to provide a new alternative to validate the contract. This corresponds to the use of a logical OR between the old and the new conditions.\r\n\r\nAll post-conditions (ensure) can be consolidate. i.e the new condition of the contract will provide a new guarantee to the user of the method. This rule can be translates into a logical AND between the old and the new conditions.\r\n\r\n### Exemple\r\n\r\n#### Expect\r\n\r\n```\r\nclass SubMyClass\r\n\tsuper MyClass\r\n\t\r\n\tredef fun foo(x: Int)\r\n\tis\r\n\t\texpects(x > 0, x == 0)\r\n\tdo\r\n\t\tfoo_expects(x)\r\n\t\t[...]\r\n\tend\r\n\t\r\n\tredef fun foo_expects(x: Int)\r\n\tdo\r\n\t\tif x == 0 then return\r\n\t\tassert super(x)\r\n\tend\r\nend\r\n```\r\n\r\n#### Ensure\r\n```\r\nclass SubMyClass\r\n\tsuper MyClass\r\n\t\r\n\tredef fun foo(x: Int): Bool\r\n\tis\r\n\t\tensures(result == true, x > 0)\r\n\tdo\r\n\t\t[...]\r\n\t\tvar result = true\r\n\t\tfoo_ensure(x, result)\r\n\t\treturn result\r\n\tend\r\n\t\r\n\tredef fun foo_ensures(x: Int, result: Bool)\r\n\tdo\r\n\t\tassert x > 0\r\n\t\tassert super(x, result)\r\n\tend\r\nend\r\n```\r\n\r\nSummary\r\n\r\n| Annotation    |  Inheritance condition type  | \r\n| ------------- | -------------| \r\n| expects       |        And (&&) |\r\n| ensures       |        Or (\\|\\|)  |\r\n\r\n## Invocation \r\n\r\nThe contracts extend the annotated methods by adding the call to the verification method. This means that once the method extended the execution of contracts will be systematically call (does not matter external or internal call). This part is subject to evolution in the months to come.\r\n","score":25.116352},{"url":"https://api.github.com/repos/nitlang/nit/issues/394","repository_url":"https://api.github.com/repos/nitlang/nit","labels_url":"https://api.github.com/repos/nitlang/nit/issues/394/labels{/name}","comments_url":"https://api.github.com/repos/nitlang/nit/issues/394/comments","events_url":"https://api.github.com/repos/nitlang/nit/issues/394/events","html_url":"https://github.com/nitlang/nit/issues/394","id":31243843,"node_id":"MDU6SXNzdWUzMTI0Mzg0Mw==","number":394,"title":"Receveurs nullables","user":{"login":"jpages","id":2535352,"node_id":"MDQ6VXNlcjI1MzUzNTI=","avatar_url":"https://avatars1.githubusercontent.com/u/2535352?v=4","gravatar_id":"","url":"https://api.github.com/users/jpages","html_url":"https://github.com/jpages","followers_url":"https://api.github.com/users/jpages/followers","following_url":"https://api.github.com/users/jpages/following{/other_user}","gists_url":"https://api.github.com/users/jpages/gists{/gist_id}","starred_url":"https://api.github.com/users/jpages/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/jpages/subscriptions","organizations_url":"https://api.github.com/users/jpages/orgs","repos_url":"https://api.github.com/users/jpages/repos","events_url":"https://api.github.com/users/jpages/events{/privacy}","received_events_url":"https://api.github.com/users/jpages/received_events","type":"User","site_admin":false},"labels":[{"id":55675455,"node_id":"MDU6TGFiZWw1NTY3NTQ1NQ==","url":"https://api.github.com/repos/nitlang/nit/labels/spec","name":"spec","color":"207de5","default":false}],"state":"open","locked":false,"assignee":null,"assignees":[],"milestone":{"url":"https://api.github.com/repos/nitlang/nit/milestones/4","html_url":"https://github.com/nitlang/nit/milestone/4","labels_url":"https://api.github.com/repos/nitlang/nit/milestones/4/labels","id":795157,"node_id":"MDk6TWlsZXN0b25lNzk1MTU3","number":4,"title":"v1.0prealpha","description":"The first public version that we are proud off and can be used sanely by non Nit people.","creator":{"login":"privat","id":135828,"node_id":"MDQ6VXNlcjEzNTgyOA==","avatar_url":"https://avatars1.githubusercontent.com/u/135828?v=4","gravatar_id":"","url":"https://api.github.com/users/privat","html_url":"https://github.com/privat","followers_url":"https://api.github.com/users/privat/followers","following_url":"https://api.github.com/users/privat/following{/other_user}","gists_url":"https://api.github.com/users/privat/gists{/gist_id}","starred_url":"https://api.github.com/users/privat/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/privat/subscriptions","organizations_url":"https://api.github.com/users/privat/orgs","repos_url":"https://api.github.com/users/privat/repos","events_url":"https://api.github.com/users/privat/events{/privacy}","received_events_url":"https://api.github.com/users/privat/received_events","type":"User","site_admin":false},"open_issues":22,"closed_issues":22,"state":"open","created_at":"2014-09-19T00:16:45Z","updated_at":"2017-06-02T12:43:15Z","due_on":null,"closed_at":null},"comments":6,"created_at":"2014-04-10T13:47:18Z","updated_at":"2015-05-21T15:19:28Z","closed_at":null,"author_association":"CONTRIBUTOR","body":"Dans le code suivant : \n\n``` ruby\n\nmodule test_nullable\n\nclass A\n    fun foo\n    do\n        print \"foo dans A\"\n    end\nend\n\nclass B\n    var p: nullable A\n\n    init\n    do\n    end\nend\n\nvar test = new B\n\n#Erreur de compilation ?\ntest.p.foo\n```\n\nOn s'attend à avoir une erreur de compilation qui nous dit que p est nullable et que cela empêche d'appeler `foo` sans faire de cast vers not null.\n\nPourtant actuellement, nit et nitg ne disent rien et une erreur est produite au runtime.\n","score":19.246428},{"url":"https://api.github.com/repos/nitlang/nit/issues/808","repository_url":"https://api.github.com/repos/nitlang/nit","labels_url":"https://api.github.com/repos/nitlang/nit/issues/808/labels{/name}","comments_url":"https://api.github.com/repos/nitlang/nit/issues/808/comments","events_url":"https://api.github.com/repos/nitlang/nit/issues/808/events","html_url":"https://github.com/nitlang/nit/issues/808","id":44962286,"node_id":"MDU6SXNzdWU0NDk2MjI4Ng==","number":808,"title":"Appel de méthodes abstraites non redéfinies","user":{"login":"colinvidal","id":7349453,"node_id":"MDQ6VXNlcjczNDk0NTM=","avatar_url":"https://avatars0.githubusercontent.com/u/7349453?v=4","gravatar_id":"","url":"https://api.github.com/users/colinvidal","html_url":"https://github.com/colinvidal","followers_url":"https://api.github.com/users/colinvidal/followers","following_url":"https://api.github.com/users/colinvidal/following{/other_user}","gists_url":"https://api.github.com/users/colinvidal/gists{/gist_id}","starred_url":"https://api.github.com/users/colinvidal/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/colinvidal/subscriptions","organizations_url":"https://api.github.com/users/colinvidal/orgs","repos_url":"https://api.github.com/users/colinvidal/repos","events_url":"https://api.github.com/users/colinvidal/events{/privacy}","received_events_url":"https://api.github.com/users/colinvidal/received_events","type":"User","site_admin":false},"labels":[{"id":55675455,"node_id":"MDU6TGFiZWw1NTY3NTQ1NQ==","url":"https://api.github.com/repos/nitlang/nit/labels/spec","name":"spec","color":"207de5","default":false}],"state":"open","locked":false,"assignee":null,"assignees":[],"milestone":{"url":"https://api.github.com/repos/nitlang/nit/milestones/4","html_url":"https://github.com/nitlang/nit/milestone/4","labels_url":"https://api.github.com/repos/nitlang/nit/milestones/4/labels","id":795157,"node_id":"MDk6TWlsZXN0b25lNzk1MTU3","number":4,"title":"v1.0prealpha","description":"The first public version that we are proud off and can be used sanely by non Nit people.","creator":{"login":"privat","id":135828,"node_id":"MDQ6VXNlcjEzNTgyOA==","avatar_url":"https://avatars1.githubusercontent.com/u/135828?v=4","gravatar_id":"","url":"https://api.github.com/users/privat","html_url":"https://github.com/privat","followers_url":"https://api.github.com/users/privat/followers","following_url":"https://api.github.com/users/privat/following{/other_user}","gists_url":"https://api.github.com/users/privat/gists{/gist_id}","starred_url":"https://api.github.com/users/privat/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/privat/subscriptions","organizations_url":"https://api.github.com/users/privat/orgs","repos_url":"https://api.github.com/users/privat/repos","events_url":"https://api.github.com/users/privat/events{/privacy}","received_events_url":"https://api.github.com/users/privat/received_events","type":"User","site_admin":false},"open_issues":22,"closed_issues":22,"state":"open","created_at":"2014-09-19T00:16:45Z","updated_at":"2017-06-02T12:43:15Z","due_on":null,"closed_at":null},"comments":2,"created_at":"2014-10-06T09:09:06Z","updated_at":"2014-10-06T13:21:53Z","closed_at":null,"author_association":"NONE","body":"Avec le code suivant \n\n```\nclass A fun foo is abstract end\nclass B super A fun bar do self.foo end end\nvar b = new B\nb.bar\n```\n\nNitg ne détecte aucune erreur (avec nitg -W il y en a beaucoup, mais rien a voir avec ça), donc ça amène à une exception à l'exécution lors de l'appel à foo sur self (var a = new A a.foo pose le même soucis).\nTesté avec version v0.6.9-12-gd65a790.\n","score":19.246391}]}