---
name: react-state-management-optimization
description: How to choose and structure React state — component vs module vs URL vs server state, contexts and context selectors, derived data and memoization, cascading updates, reducers, refs, synchronization, batching, and effects. The core invariant is that one update produces one render pass. Use before writing or refactoring any React state management, adding a context/store/atom, adding a useEffect that touches state, or debugging unnecessary rerenders, stale values, tearing, or render loops.
---

# React State Management

**The invariant: one update produces one render pass.** An update must never produce multiple
rerenders. When it does, the cause is almost always an effect that sets state, and it is wrong —
see [Cascading Updates](#cascading-updates). Fix it; do not optimize around it.

Prior to React, popular frameworks like AngularJS (2010) followed the Model-View-Whatever
paradigm. In these frameworks, the model manages the data and business logic, and the view
manages the user interface.

In Model-View-Whatever, both the model and the view are mutable and have their own state. Model
state and view state must be kept in sync; therefore, when one is mutated, it mutates the other to
match. This is called **two-way data binding**. However, the React team noticed that:

> Two-way data bindings led to cascading updates, where changing one object led to another object
> changing, which could also trigger more updates. As applications grew, these cascading updates
> made it very difficult to predict what would change as the result of one user interaction. When
> updates can only change data within a single round, the system as a whole becomes more
> predictable. (Flux)

React (2013) eschewed two-way data binding, instead modeling the application as a pure function
from `State -> View`. The view is stateless, immutable, and ephemeral; when the state updates,
React computes a brand new view to replace the old. Since the state is a single source of truth,
no cascading updates are necessary. This is called **unidirectional data flow**.

React decomposes the view into components, each of which is a `State -> View` function. Small
components compose larger components; their hierarchy forms the component tree. React renders the
view by calling the root function of the component tree. When the state updates, React rerenders
the component subtrees that depend on the updated state.

## Motivation

React was a library that encapsulated logic for (re)rendering the view and applying DOM mutations.
Although React provided the means for creating component-scoped state, it broadly lacked opinions
on state management.

In the decade since its inception, React has gradually added more builtins for state management,
such as Context (2018). The present builtins suffice for managing the state of simple
applications. However, for applications of nontrivial scale and complexity, the present builtins
fail to robustly and performantly manage state. More specifically, they struggle to maintain four
qualities:

1. **Structure**, such that relationships are clear and transformations are predictable.
2. **Performance**, such that unnecessary rerenders do not slow the interface.
3. **Scope**, such that state is accessible without compromising structure or performance.
4. **Convenience**, such that boilerplate is minimized and developer experience improved.

Additional state management patterns are required to maintain these qualities. Over the years,
each new state management library has attempted to succeed their predecessors in these qualities.

State can furthermore be divided into four types: **component**, **module**, **URL**, and
**server**. Each differs in structure, performance characteristics, and scope. The next four
sections introduce each type of state, their management patterns, and notable libraries.

## Component State

Component state is defined inside a component's scope, typically with the builtin `useState` hook.
It can only be accessed by that component's subtree; consequently, the structure of the component
state graph (including data derived from component state) mirrors the structure of the component
tree.

```tsx
const Component = ({ user }) => {
  const [state, setState] = useState(0);
  ...
};
```

The locality and restricted scope of component state makes it perfect for **local state**, or
state depended on by a single component and its subtree. The inability for unintended components
to access the state grants it predictability.

On the other hand, its locality chafes against **shared state**, or state depended on by multiple
distant component trees. To make component state accessible to distant component trees, the state
must be lifted up into the lowest common ancestor component, which itself has no need for the
state.

Lifting state up, however, introduces unnecessary rerenders. Take the following component tree:

```
Page (common ancestor; defines User state)
  Header
    Navigation
    Profile (depends on User state)
  Body
    CallToAction
    Information (depends on User state)
```

For the same reason a function must call its sub-functions to compute its result, a component must
call its sub-components to render its view. Therefore, when the User state updates, `Page` and all
its children also rerender. Since only `Profile` and `Information` change, there are five
unnecessary rerenders. For large component trees with rapidly updating state, the unnecessary
rerenders can cause a performance problem.

Additionally, after state is lifted up, it must be threaded through the component tree to each of
its dependent components. In deep component trees, the modification of every intermediate
component's props is very inconvenient. This is known as the **prop drilling** problem. Prop
drilling can often be mitigated by flattening the component tree through conscientious use of the
`children` prop. Passing state via props then remains convenient, explicit, and predictable.

However, deep component trees are sometimes justified. The next two sections, Contexts and Context
Selectors, introduce patterns which resolve component state's prop drilling and performance
problems.

### Contexts

Context (2018), a builtin, solves the prop drilling problem. Contexts provide data to entire
component trees, such that intermediate components between the context provider and the context
consumers remain unaware and unmodified.

```tsx
const UserContext = ({ user }) => (
  <Context value={user}>
    <Header />
    <Body />
  </Context>
);

const Profile = () => {
  const user = useContext(Context);
  ...
};
```

The previous example, updated to use context, produces:

```
Page (defines User state)
  UserContext (provides User state)
    Header
      Navigation
      Profile (consumes User state)
    Body
      CallToAction
      Information (consumes User state)
```

However, context, as used above, did not remove any unnecessary rerenders; in fact, it made the
problem worse by introducing another component that must be rerendered. Fortunately, dispensing
with props enables two methods for eliminating unnecessary rerenders:

1. Memoize the children of `UserContext`. This prevents `Header` and `Body` from rerendering when
   the User state updates. An update to `UserContext`'s value will skip the intermediate
   components and directly cause `Profile` and `Information` to rerender.

   ```tsx
   const UserContext = ({ user }) => (
     <Context value={user}>
       {useMemo(
         () => (
           <>
             <Header />
             <Body />
           </>
         ),
         []
       )}
     </Context>
   );
   ```

2. Push the User state down into `UserContext` and pull `UserContext`'s component subtree up into
   `Page`. Now a mutation to the User state only rerenders `UserContext` and its consumers.

   ```tsx
   const UserContext = ({ children }) => {
     const user = ...;
     return <Context value={user}>{children}</Context>;
   };

   const Page = () => (
     <UserContext>
       <Header />
       <Body />
     </UserContext>
   );
   ```

   But why does pulling `Header` and `Body` up into `Page` and then passing them back to
   `UserContext` as children remove them from `UserContext`'s component subtree?

   Remember that the component tree is a tree of functions. The tree of functions is not the tree
   of HTML elements; the tree of functions returns the tree of HTML elements when called.
   Parent-child relationships in the component tree of functions are defined by parent function
   calling child function.

   The `Header` and `Body` component functions are now called inside the `Page` component
   function. Only their rendered output is passed to `UserContext`.

   When the User state updates, `UserContext` rerenders with a cached `children` prop containing
   the rendered output of `Header` and `Body`. `UserContext` calls no other component functions.
   Therefore, `Header` and `Body` do not unnecessarily rerender.

The above two optimizations prevent non-context consumers from unnecessarily rerendering. For
small single-value contexts, this eliminates all unnecessary rerenders. But for large object
contexts, there may still be unnecessary rerenders. Take the following example:

```
UserContext
  ProfileLink (consumes User.ID state)
  NameCard (consumes User.Name state)
  WelcomeBack (consumes User.LastSeen state)
  Fire (consumes User.PowerLevel state)
```

When the `User.PowerLevel` state updates, all four context consumers rerender, three of them
unnecessarily. This is the **large context problem**.

One pattern that solves the large context problem is context-splitting, in which one large context
is split into multiple smaller contexts. Like so:

```
Page (defines User state)
  UserIDContext
    UserNameContext
      UserLastSeenContext
        UserPowerLevelContext
          ProfileLink (consumes User.ID state)
          NameCard (consumes User.Name state)
          WelcomeBack (consumes User.LastSeen state)
          Fire (consumes User.PowerLevel state)
```

However, it is inconvenient to define so many context providers. The number of context providers
must also be static, making this pattern incompatible with dynamic-length arrays.

#### Context Selectors

Context selectors (2019) provide a more convenient and array-compatible solution to the large
context problem. They are suitable as a general-purpose state management pattern without
performance footguns.

```tsx
const ProfileLink = () => {
  const userID = useContextSelector(Context, c => c.id);
  ...
};
```

Context consumers use a selector function to select a value from the context.

When the context's value updates, the context runs every consumer's selector function and compares
the output to its previous output. Only if the output of its selector has changed does a consumer
rerender.

Context selectors are currently a pending RFC (RFC 119); `use-context-selector` (2019) provides a
userspace implementation.

#### Context Loss

Renderers, such as `react-three-fiber` and `react-pdf`, translate React components into something
besides HTML elements. Specialized component subtrees can be configured to use an alternative
renderer inside an otherwise `react-dom` renderer driven application.

However, contexts stop at renderer boundaries. The components of one renderer cannot access data
provided by contexts of another renderer. This is known as the **context loss** problem. It can be
solved by manually forwarding the outer context's data into a new context within the nested
renderer; however, this causes the nested renderer's entire component tree to rerender whenever the
context value updates, so careful memoization is required to prevent the unnecessary rerenders.

Module state does not suffer from the context loss problem; applications with significant state
sharing between renderers may favor module state.

### Derived Data

The state graph is a directed graph of state and its **derived data**, or the data and functions
derived from state. State are the source vertices; they are not computed as a function of
something else.

Data derived from component state is computed inside a component's scope. Thus, just like
component state, its structure mirrors the component tree, and it can be passed through props and
contexts.

One common anti-pattern is to structure derived data as **derived state**. If some state can be
derived as a function of other state, it should instead be a computation. For example:

```tsx
const DerivedState = () => {
  const [count, setCount] = useState(0); // State.
  const [double, setDouble] = useState(0); // Derived state.
  const onClick = () => {
    setCount(count + 1);
    setDouble((count + 1) * 2);
  };
  return (
    <button onClick={onClick}>
      {count}/{double}+
    </button>
  );
};

const DerivedData = () => {
  const [count, setCount] = useState(0); // State.
  const double = count * 2; // Derived data.
  const onClick = () => setCount(count + 1);
  return (
    <button onClick={onClick}>
      {count}/{double}+
    </button>
  );
};
```

`DerivedData` makes the relationship between `count` and `double` much clearer and is more robust
to future code changes than `DerivedState`. As a rule, reducing state increases robustness.
Therefore, avoid derived state and favor derived data.

#### Memoization

By default, derived data is recomputed in each render. If the computation is expensive, this can
create a performance problem. To solve this, expensive derived data computations can be memoized
with the `useMemo` and `useCallback` hooks (hereafter simply `useMemo`).

```tsx
const useExpensiveData = (dep1) => {
  const dep2 = ...;
  return useMemo(() => expensive(dep1, dep2), [dep1, dep2]);
};
```

`useMemo` accepts an array of the derived data's dependencies and only recomputes the derived data
when a dependency changes. This introduces two footguns:

1. If a dependency is accidentally omitted from the dependency array, the derived data can become
   stale. This may be linted against with the (mandatory) `eslint-plugin-react-hooks`.

2. Dependency changes are computed with `Object.is`, which performs a referential equality
   comparison on objects. If dependencies are not referentially stable across renders, `useMemo`
   will always recompute, defeating the point of memoization. For example:

   ```tsx
   const useBroken = (dep1) => {
     const dep2 = { im: "a new object each render" };
     return useMemo(() => expensive(dep1, dep2), [dep1, dep2]);
   };
   ```

   To fix this, the object dependency must either be moved to module scope or also be memoized.
   Like so:

   ```tsx
   const dep1 = { im: "just a constant" };
   const useFixed = () => {
     const dep2 = useMemo(() => ({ im: "the same object each render" }), []);
     return useMemo(() => expensive(dep1, dep2), [dep2]);
   };
   ```

   However, it only takes one unmemoized object dependency to break memoization. In large state
   graphs, it is easy to miss a transitive dependency, thus breaking memoization. The "memo all
   the things" philosophy addresses this problem by preemptively memoizing every object.

   A competing philosophy, "optimize responsibly," promotes on-demand optimization to avoid
   unnecessarily introducing memoization overhead. Both philosophies are reasonable; suitability
   depends on the problem space and application type.

#### Cascading Updates

A properly structured state graph is a **directed acyclic graph (DAG)**, meaning that derived data
should flow from parent component to child component and top-down within each component. However,
it is possible to compute derived state with the `useEffect` hook and cause state to flow upwards.
For example:

```tsx
const Bad = () => {
  const [derived, setDerived] = useState(0); // Depends on `state`.
  const [state, setState] = useState(0); // Defined below its dependent.
  useEffect(() => setDerived(state + 1), [state]);
  const onClick = () => setState((x) => x + 1);
  return <button onClick={onClick}>{derived}+</button>;
};
```

`Bad` requires multiple rerenders to fully recompute the state graph. On click, `state = 1` and
the component rerenders in response. After the rerender, the effect runs and `derived = 2`,
causing a second rerender in response. Only after the second rerender is the view updated. This is
known as **cascading updates**.

Cascading updates break unidirectional data flow. Remember that React applications are functions
from `State -> View`. But when the render function has a side effect that mutates state, the
application becomes `State <-> View`. This is reminiscent of two-way data binding:

> Two-way data bindings led to cascading updates, where changing one object led to another object
> changing, which could also trigger more updates. As applications grew, these cascading updates
> made it very difficult to predict what would change as the result of one user interaction. When
> updates can only change data within a single round, the system as a whole becomes more
> predictable. (Flux)

Cascading updates also amplify renders and are thus unperformant. They can introduce circular
dependencies, breaking the DAG and potentially causing an infinite render loop. **Without
cascading updates, state updates never cause a second render pass, much less an infinite loop.**

```tsx
const DoesThisInfiniteLoop = () => {
  const [derived, setDerived] = useState(0);
  const [state, setState] = useState(0);
  const funny = derived ? state : derived;
  useEffect(() => setDerived(funny + 1), [funny]);
};
```

Therefore, **`useEffect` should never be used to derive state.** Instead, lift state up and
reorder statements such that all derived data has access to its dependencies. In this way, state
can flow in a single downwards direction and completely recompute in a single render.

### Reducers

The builtin `useReducer` hook (2019) is an alternative to `useState`. The reducer pattern
colocates state with its transformations, improving predictability at the cost of boilerplate.

```tsx
const Counter = () => {
  const [state, dispatch] = useReducer((state, action) => {
    if (action.type === "add") {
      return state + action.payload;
    } else if (action.type === "sub") {
      return state - action.payload;
    } else {
      throw new Error(`Invalid action ${action.type}`);
    }
  }, 0);
  const onClick = () => dispatch({ type: "add", payload: 1 });
  return <button onClick={onClick}>{state}+</button>;
};
```

`useReducer` is equivalent in theoretical expressiveness to `useState`. `useState` is even
implemented with `useReducer` under the hood. Thus, for the most part, `useReducer` is simply an
alternative pattern for structuring state. `dispatch` also gives `useReducer` slightly better
render performance than `setState` since its identity never changes and its business logic is
updatable between renders, so it will never break memoization.

### Refs

State defined with the builtin `useState` or `useReducer` hook is **immutably updated**; new
values replace the old values instead of mutating them.

Refs contain component state that is **mutably updated** and thus does not cause rerenders. Refs
are an escape hatch enabling behaviors not possible with immutable updates, but can easily cause
bugs. Whenever possible, `useState` should be preferred over `useRef`.

React models components as pure functions from `State -> View`. This functional purity powers
**concurrent mode**, in which React concurrently executes several renders and may pause or abandon
in-progress renders.

Mutable state breaks functional purity and can become inconsistent in concurrent mode rendering;
therefore, **refs should not be read or mutated during render**. Refs should only be used for
state unrelated to rendering the user interface. There are few exceptions; tread carefully.

Refs can parametrize recurring effects. Updating a ref does not cause effects to rerun.

Refs can also resolve performance problems. The following example would cause a rerender every
millisecond with `useState`:

```tsx
const useShowBug = () => {
  const position = useRef(0);
  useEffect(() => {
    // The bug jitters across the number line.
    const interval = setInterval(() => {
      position.current += Math.random() * 2 - 1;
    }, 1);
    return () => clearInterval(interval);
  }, []);
  return () => alert(`The bug is currently at ${position.current}.`);
};
```

To track previous versions of state, refs are unnecessary; `useState` or `useReducer` can and
should be used, like so:

```tsx
const usePreviousState = () => {
  const [[state, previousState], setState] = useReducer(
    ([state], newState) => [newState, state],
    [0, null]
  );
  return { state, previousState, setState };
};
```

## Module State

Module state is defined in **module scope**, decoupled from the component tree. It may be read and
updated by non-React code.

Module state is thus inherently framework-agnostic; all module state libraries can be integrated
with other non-React frameworks like Vue.js and SolidJS, even in the same codebase.

```tsx
// The simplest production-ready module state, Zustand.
const store = createStore(() => 0);

const Component = () => {
  const state = useStore(store);
  const onClick = () => store.setState((x) => x + 1);
  return <button onClick={onClick}>{state}+</button>;
};
```

Module state is initially scoped to a single module, granting some locality. However, it is often
exported from that module, allowing every other module and component to access it. This allows
module state to be easily shared between distant component subtrees without the inconvenience of
prop drilling or the performance problems of lifting state up.

However, as more components depend on the module state and introduce their own mutations, the
state can become unpredictable. At its worst, each component becomes intricately coupled with the
state's transformations, making it difficult to add or remove features that depend on the state.
The often-unrestricted scope of module state is a double-edged sword.

Module state resolves problems with frequently updated shared state in large component trees. For
state scoped to a single component's subtree, prefer component state and its locality.

Being decoupled from the component tree, module state has complete flexibility in its structure
and semantics. This has resulted in many novel state management patterns; four of which have
gained prominence over the others. They are the Flux, observable, atom, and state machine
patterns.

### Flux

In 2014, Facebook (i.e. the React team) presented Flux, their then-internal pattern for managing
complex state. Flux embraced unidirectional data flow and tailored itself to React's
`State -> View` model.

In Flux, an application has multiple stores. Stores are objects that encapsulate the state and its
possible mutations. Predefining all state mutations within the store keeps state transformations
predictable despite the state's unrestricted scope.

Consumers dispatch actions, a type and payload tuple, to a centralized dispatcher, which forwards
actions to every store. Stores determine which mutation to run from the action type and
parametrize it with the action payload. A single action can cause multiple stores to mutate
themselves. After mutating themselves, stores emit change events. React components subscribe to
change events and rerender whenever they receive them. This synchronization ensures that the view
correctly reflects the latest state.

Redux (2015), short for Reducers + Flux, simplified Flux and introduced immutable state updates.
Redux has one monolithic store which directly receives actions, eliminating the dispatcher. Redux
also structured state transformations as a single large pure reducer function instead of mutable
objects. The purity of the reducer function enabled the extremely useful **time travel
debugging**.

```tsx
// A simple counter in Redux.
const store = createStore((state = { value: 0 }, action) => {
  if (action.type === "add") {
    return { value: state.value + action.payload };
  } else if (action.type === "sub") {
    return { value: state.value - action.payload };
  } else {
    return state;
  }
});

const Counter = () => {
  const state = useSelector((store) => store.value);
  const dispatch = useDispatch();
  const onClick = () => dispatch({ type: "add", payload: 1 });
  return <button onClick={onClick}>{state}+</button>;
};

const App = () => (
  <Provider store={store}>
    <Counter />
  </Provider>
);
```

Redux was unopinionated on the structure of actions and reducers, leading the community to develop
several competing boilerplate-heavy conventions. In 2019, the Redux team released **Redux Toolkit
(RTK)**, an opinionated approach to Redux that simplified common patterns and smoothed over
pitfalls.

**Zustand** (2019) is another simplification of Flux with fewer opinions and boilerplate than
Redux. It is the smallest and simplest production-ready module state management library. Zustand
stores expose multiple functions that immutably update the state. Consumers directly call these
functions.

```tsx
// A simple counter in Zustand.
const useStore = create((set) => ({
  value: 0,
  add: (payload) => set((state) => ({ value: state.value + payload })),
  sub: (payload) => set((state) => ({ value: state.value - payload })),
}));

const Counter = () => {
  const { value, add } = useStore();
  const onClick = () => add(1);
  return <button onClick={onClick}>{value}+</button>;
};
```

Zustand and Redux are analogous to `useState` and `useReducer`. Through its single reducer
function, Redux forcibly colocates all state updates in a single place for predictability. Zustand
allows the developer their choice of methods for keeping state predictable (or not).

By default, components subscribe to all updates on a store. Large stores thus lead to many
unnecessary rerenders. Flux libraries apply the selector pattern to eliminate unnecessary
rerenders.

```tsx
// Selectors in Zustand.
const Counter = () => {
  const state = useStore(store => store.value);
  const add = useStore(store => store.add);
  ...
};
```

Flux libraries also support computing derived data within selectors. However, since selectors run
on every store update, expensive derived data computations must be memoized.

```tsx
// Derived data in Zustand selector.
const DoubleCounter = () => {
  const double = useStore(store => store.value*2);
  ...
};
```

### Observables

**MobX** (2016) structures state stores as mutable JavaScript objects, eschewing the boilerplate
of immutable updates and suboptimal selector-based render optimization.

MobX modifies JavaScript objects to intercept property accesses on the stores, precisely tracking
the properties each component depends on during render. MobX also intercepts mutations on the
stores to emit change events to React components. Because MobX knows the precise dependencies of
each component and precisely which state was mutated, it automatically and perfectly optimizes
renders without selectors or dependency arrays.

MobX also applies property tracking to perfectly memoize derived data computations. To enable
this, MobX colocates state, derived data, and mutations inside its stores. Like Flux, this
colocation keeps state transformations predictable.

```tsx
// A simple counter in MobX.
const store = makeAutoObservable({
  state: 0,
  add(payload) {
    this.state += payload;
  },
  sub(payload) {
    this.state -= payload;
  },
  get double() {
    return this.state * 2;
  },
});

const Counter = observer(() => {
  const onClick = () => store.add(1);
  return (
    <button onClick={onClick}>
      {store.state}/{store.double}+
    </button>
  );
});
```

**Valtio** (2021) is a modern simplification of the observable pattern with a hooks-based API.
Unlike MobX, mutations and derived data need not be methods on the store, and components need not
be wrapped in observers. Like Zustand, Valtio does not enforce the colocation of derived data and
mutations; consumers can use alternative methods to keep state predictable.

```tsx
// A simple counter in Valtio.
const state = proxy({ value: 0 });
const add = (payload) => {
  state.value += payload;
}; // Can also be
const sub = (payload) => {
  state.value -= payload;
}; // a method.
const double = derive({ value: (get) => get(state).value * 2 });

const Counter = () => {
  const snap = useSnapshot(state);
  const snap2 = useSnapshot(double);
  const onClick = () => add(1);
  return (
    <button onClick={onClick}>
      {snap.value}/{snap2.value}+
    </button>
  );
};
```

A significant downside of observables is that they introduce a mutable update pattern into an
otherwise immutable updates-based application, requiring constant switching between the two styles
depending on the type of state being developed.

Furthermore, combining observable state and immutable state requires compromise. Combining MobX
state with component state in `useMemo` and `useEffect` requires a nuanced ceremony. Valtio chose
to give up on perfect render optimization to avoid this ceremony.

### Atoms

Contexts often hoist much state to the root of the application. When **code splitting**, none of
that state can be split out from the main bundle. Flux is even more egregious; since all state is
typically combined into a single store, the entire store must be included in the main bundle.

In applications with lots of shared state, this significantly increases the bundle sizes. Recoil
(2020, unmaintained) solves this problem by distributing the state graph into many small units
called **atoms**. Each atom is only bundled with the components that depend on it, allowing the
state to be efficiently code split.

Derived atoms compute and store derived data. All atoms have the same interface, allowing state
atoms to be swapped with derived atoms, and vice versa, without needing to modify consumers. This
further decouples the state graph from the component tree.

Atoms can be scoped to a single module. This protects part of the state graph from unwanted
consumers, something other module state solutions cannot accomplish. Hence, atoms are also
suitable for local state.

Components subscribe to the change events of individual atoms. Since atoms are typically scalar
values or small objects, there are few unnecessary rerenders. Although not as perfect as
observables, atoms improve upon Flux since they need no selectors.

**Jotai** (2020) was released six months after Recoil, simplifying Recoil's API and reducing the
bundle size by 90%.

```tsx
// A simple counter in Jotai.
const stateAtom = atom(0);
const doubleAtom = atom((get) => get(stateAtom) * 2);

const Counter = () => {
  const [state, setState] = useAtom(stateAtom);
  const double = useAtomValue(doubleAtom);
  const onClick = () => setState(state + 1);
  return (
    <button onClick={onClick}>
      {state}/{double}+
    </button>
  );
};
```

Jotai released integrations that convert all non-component state and their popular libraries into
atoms. Jotai, being suitable for both local and shared state and integrated with all state types,
is capable of representing an application's entire state graph as atoms. It is the most complete
state management library.

### State Machines

State machines are a pattern for structuring state that capture all possible states, the
transitions between states, and the events that cause transitions. By colocating all state
transformations and bucketing them into explicit states, state machines improve predictability to
the soft limit.

Consider augmenting other state management patterns with state machines in complicated features
and multi-step flows. Simple state machines can be implemented with the `useState` and
`useReducer` hooks, or within the other module state patterns. Complex state machines may benefit
from XState (2017).

### Componentization

The unrestricted scope of most module state is suboptimal for state consumed only by a single
component tree. The locality and restricted scope of component state prevents its misuse. However,
module state patterns provide more powerful structures than React's builtin `useState` and
`useReducer` hooks. When such power is needed, module state patterns can be used to define
component state. For example:

```tsx
const Componentization = ({ children }) => {
  const store = useRef(null);
  if (store.current === null) {
    store.current = createStore(); // No longer module state.
  }
  return <Context value={store}>{children}</Context>;
};
```

Module state can also be integrated into the component tree in order to propagate it to all
components, such that they need not all import the store. This is what Redux does. For example:

```tsx
const store = createStore(); // Still module state.

const PropagateStore = ({ children }) => {
  return <Context value={store}>{children}</Context>;
};
```

## URL State

One often overlooked state is the URL. Traditionally, the URL determines one's location in the
application. Application state can be stored in the URL's path, **search parameters**, and hash.

Unlike component state and module state, URL state is persisted across page reloads. Thus, it can
also be conveniently shared between users and bookmarked in the browser.

URL state can be read from `window.location` and manually synchronized. However, applications will
have a routing library like React Router, TanStack Router, or wouter; these libraries manage and
synchronize URL state.

## Server State

The three types of state introduced thus far—component state, module state, and URL state—are
ephemeral client-side state. Most applications have a server that contains large amounts of
long-term persistent state. When those applications start, they fetch that **server state**.

Server state is complicated due to the network boundary; network requests have nontrivial latency
and can fail. It is possible to naively implement server state reads with a combination of
`useEffect` and `fetch`.

```tsx
const useServerState = () => {
  const [state, setState] = useState(undefined);
  useEffect(() => {
    (async () => {
      const resp = await fetch("/api/data");
      setState(await resp.json());
    })();
  }, []);
  return state;
};
```

However, production-ready data fetching requires many additional features. **TanStack Query**
(2020) and **SWR** (2021) implement those features and many more; prefer using them over
reimplementing them.

Since server state belongs to the server, its structure is determined by the server's API. When
the server state structure does not match the frontend application's data model, it can be
restructured as derived data. For example:

```tsx
const useRestructuredState = () => {
  // Loading states and error handling left as an
  // exercise to the reader. Please don't skip them!
  const { data: data1, ... } = useQuery(...);
  const { data: data2, ... } = useQuery(...);
  return { newData: data1.x, otherNewData: data2.y };
};
```

Server state is effectively in global scope since all modules can make network requests to the
server. Server state libraries also cache server state inside a module state store; hence, all
components default to sharing a single copy of the cached server state.

Components subscribe to change events on individual network requests, and rerender when those
specific network requests are updated in the cache. Components rarely depend on every property of
a network request and can thus unnecessarily rerender. However, since network requests are
infrequently updated, this rarely causes performance problems.

### Cache Invalidation

In addition to fetching server state, applications also request the server to mutate it. After the
server mutates its state, a subset of the frontend application's cached server state becomes stale
and incorrect. Applications must identify the stale state and invalidate it. This is known as the
**cache invalidation** problem.

Cache invalidation is hard and lacks a general solution; the viability of each solution depends on
the server's API structure. Regardless, a messy server API makes cache invalidation difficult
regardless of the solution.

Some common patterns for server state cache invalidation are:

1. After each mutation, invalidate the entire cache. This guarantees correctness, but causes
   unnecessary refetches. This pattern works very well after infrequent mutations. If used after
   frequent mutations, such as a Like! button, the unnecessary refetches can create a performance
   or server load problem.
2. After each mutation, handpick the cached requests to invalidate. This does not guarantee
   correctness, but eliminates unnecessary refetches. If a view only depends on a few
   well-designed requests, this method is practical. If a view depends on many poorly-designed
   requests, this method will cause bugs.
3. Correlate all server state with the mutations that change them. After each mutation, invalidate
   the correlated requests. This guarantees both correctness and performance, but establishing and
   maintaining the correlation graph is difficult, especially in large organizations.
4. Enforce API conventions which normalize the server state and make correlations between state
   and mutations easily inferable. This typically manifests as REST or GraphQL. However, these
   conventions require extra ceremony and complexity in the server. Normalized REST APIs introduce
   many network requests, and GraphQL is prone to performance problems.

In choosing patterns for cache invalidation, applications make tradeoffs between incorrectness,
unnecessary network requests, and server complexity. The optimal tradeoff depends on the problem
at hand, application type, and team solving it.

## Composite Derived Data

Each state management pattern can derive and memoize data from its own state. Component state has
`useMemo`, Flux has selectors, observables have getter methods, and atoms have derived atoms. But
how can data derived from multiple types of state, or **composite derived data**, be computed?

Several module state libraries integrate other types of non-component state. For example, Redux
has RTK Query for server state, and Jotai has many extensions. If the derived data's dependencies
are all integrated into a single module state store, the derived data can be computed in that
state store.

Otherwise, composite derived data can be computed in the React component tree, the inevitable
meeting point and common integration of all state. Additionally, if composite derived data depends
on component state, it must be computed in the component tree since, in line with unidirectional
data flow, non-component state can flow into the component tree, but not vice versa.

```tsx
const useStore = zustand.create(...);

const useCompositeDerivedData = () => {
  const [reactState, setReactState] = useState(0);
  const zustandState = useStore(store => store.value);
  const { data: serverState } = useQuery(...);
  return reactState + zustandState + serverState;
};
```

Composite derived data computed in the component tree is essentially component derived data and
therefore subject to its problems and optimizations, notably restricted scope and contexts.

One anti-pattern for circumventing context's performance problem is to synchronize composite
derived data back into module state. For example:

```tsx
const useStore = zustand.create(...);

const useHook = () => {
  const [x, setX] = useState(0);
  const y = useStore(store => store.y);
  const setZ = useStore(store => store.setZ);
  useEffect(() => setZ(x + y), [x, y, setZ]);
};
```

However, this reintroduces cascading updates. Instead, the performance problems of contexts can be
resolved with context selectors.

## Synchronization

For React to rerender in response to state updates, React must be aware of state updates. React is
inherently aware of updates made to builtin `useState` and `useReducer` state. However, React is
not inherently aware of updates in external (non-builtin) state stores, which includes module
state, URL state, and server state. Thus, external state stores must themselves cause their
dependent components to rerender on state updates. This is known as **synchronization**.

Synchronization is typically implemented with the **observer pattern**. Components subscribe
themselves to a store. When the store updates, it notifies all subscribers to trigger a rerender.

Synchronization is not perfect; over the years, several incompatibilities between external state
and React's rendering model have surfaced, most notably concurrent mode.

### Concurrent Mode

In the past, each render pass would synchronously run start to end without any interruptions.
During long-running renders, the application would become unresponsive. React 18 (2022)
introduced **concurrent mode**, which made rendering interruptible. Expensive renders could be
time sliced into small pieces of work, interspersed between browser events and more important
renders. This allowed an application to remain responsive throughout a long-running render.

React's `State -> View` model relies on the state remaining unchanged throughout a render pass. In
synchronous mode, since React never gives up control over the thread, no other code has the
opportunity to update the state. Even mutable state is guaranteed to remain unchanged throughout a
render pass.

That changes in concurrent mode. External state is typically consumed by multiple components. If
those components are part of different time slices, and the state is updated in between those time
slices, the final view can reflect different states. For example:

```tsx
const useStore = zustand.create(...);
const Echo = () => <div>{useStore()}</div>;
const Tear = () => <div><Echo /><Echo /><Echo /></div>;
```

If the store is updated in between each `<Echo />`'s render, the final view will reflect three
different versions of the store's state. This problem is called **tearing**.

The builtin `useState` and `useReducer` hooks solve tearing through branching. They return the
same snapshot of the state throughout a time sliced render, even if updated.

However, branching currently depends on React internals, which external state cannot use. Thus, to
solve tearing in external state, React 18 introduced the `useSyncExternalStore` hook (RFC 214). It
replaced the previous pattern for subscribing to external state.

```tsx
const useStore = () => {
  const value = useSyncExternalStore(store.subscribe, () => store.value);
  return value;
};
```

Rerenders triggered through `useSyncExternalStore` do not run in concurrent mode. Instead, they
de-opt from concurrent mode and run "sync"hronously, which naturally solves the tearing problem.
However, the long-running render problem solved by concurrent mode is reintroduced.

Jotai notably does not use `useSyncExternalStore` in order to opt-into concurrent mode. As a
consequence, Jotai is subject to tearing. Currently, no external state is fully compatible with
time slicing. All external state must choose between synchronicity or tearing.

## Batched Updates

Builtin state updates (`useState` and `useReducer`) can run either synchronously or
asynchronously. When run synchronously, they immediately trigger a rerender in the component they
belong to. When run asynchronously, the update is enqueued and does not immediately cause a
render. Upon render, all enqueued asynchronous state updates are batched into a single render
pass. This avoids unnecessary rerenders. For example:

```tsx
const FlowerPowers = () => {
  const [color1, setColor1] = useState("orange");
  const [color2, setColor2] = useState("purple");
  const onClick = () => {
    setColor1("brown");
    setColor2("red");
  };
  return (
    <button onClick={onClick}>
      swap {color1} {color2}
    </button>
  );
};
```

If the state updates within `onClick` run synchronously, the component will rerender twice per
click. But if the state updates run asynchronously, React can batch them into a single render
after the event handler returns.

Before React 18 (2022), only state updates inside event handlers were batched. In React 18, React
automatically batches all state updates by default. Updates can be made synchronous with the
`flushSync` function.

## Effects

React components are pure functions; they cannot cause side effects when rendering. Side effects
must be scheduled to run after render with the `useEffect` hook.

Many useful behaviors are side effects: synchronizing with external (non-builtin) state,
configuring intervals, and making network requests. These are all implemented with `useEffect`.

However, `useEffect` is not a general utility for all application side effects. It is intended
specifically for **side effects of rendering**. If the root cause of a side effect is not
rendering, but an event handler or an interval, `useEffect` should not be used. For example:

```tsx
const useBad = () => {
  const [state, setState] = useState(0);
  useEffect(() => {
    if (state) {
      alert(`Your new lucky number is ${state}!`);
    }
  }, [state]);
  const onClick = () => setState(Math.floor(Math.random() * 100 + 1));
  return <button onClick={onClick}>Reroll {state}!</button>;
};

const useGood = () => {
  const [state, setState] = useState(0);
  const onClick = () => {
    const lucky = Math.floor(Math.random() * 100 + 1);
    setState(lucky);
    alert(`Your new lucky number is ${lucky}!`);
  };
  return <button onClick={onClick}>I'm feeling lucky!</button>;
};
```

In `useBad`, the side effect is separated from the event that causes it. It runs one rerender after
the event handler; this is fragile and lacks predictability. In `useGood`, the side effect is
colocated with the action that causes it; this is robust and predictable.

State updates are also side effects. However, **state should never be updated from a `useEffect`
hook except to synchronize it with an external system**, because it otherwise leads to cascading
updates.
