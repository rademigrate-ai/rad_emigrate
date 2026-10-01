# RAD Emigrate Architecture

## Overview

RAD Emigrate uses a feature-first Flutter architecture.

## Layers

Presentation -> Domain -> Data -> External Services

- Presentation contains widgets, controllers and state.
- Domain contains entities and contracts.
- Data contains repositories and data sources.
- External services contain storage, networking and integrations.

## Structure

```
lib/
 app/
 core/
 features/
```

Features are isolated and can evolve independently.
