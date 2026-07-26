<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import '$lib/index.css';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<div class="app">
	<nav class="sidebar">
		<span><a href="/">home</a></span>
		<span><a href="/browse">browse</a></span>
		<span><a href="/create">create</a></span>
		<span><a href="/about">about</a></span>
	</nav>
	<div class="mainContent">
		{@render children()}
	</div>
</div>
