import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// A list of skeleton cards mimicking TurfCard items
class TurfListSkeleton extends StatelessWidget {
  const TurfListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(height: 180, borderRadius: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Skeleton(width: 140, height: 20),
                          Skeleton(width: 60, height: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Skeleton(width: 200, height: 14),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Skeleton(width: 60, height: 22, borderRadius: 6),
                          SizedBox(width: 8),
                          Skeleton(width: 65, height: 22, borderRadius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A list of skeleton cards mimicking Match/Event cards
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Skeleton(width: 60, height: 18, borderRadius: 6),
                      Skeleton(width: 50, height: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Skeleton(width: 180, height: 20),
                  const SizedBox(height: 8),
                  const Skeleton(width: double.infinity, height: 14),
                  const SizedBox(height: 4),
                  const Skeleton(width: 220, height: 14),
                  const Divider(height: 24),
                  Row(
                    children: const [
                      Skeleton(width: 16, height: 16, borderRadius: 8),
                      SizedBox(width: 6),
                      Skeleton(width: 120, height: 14),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Skeleton(width: 16, height: 16, borderRadius: 8),
                          SizedBox(width: 6),
                          Skeleton(width: 90, height: 14),
                        ],
                      ),
                      Row(
                        children: const [
                          Skeleton(width: 16, height: 16, borderRadius: 8),
                          SizedBox(width: 4),
                          Skeleton(width: 60, height: 14),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A list of skeleton tiles mimicking Player list tiles
class PlayerListSkeleton extends StatelessWidget {
  const PlayerListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: ListTile(
              leading: const Skeleton(width: 40, height: 40, borderRadius: 20),
              title: const Skeleton(width: 120, height: 16),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: const Skeleton(width: 80, height: 12),
              ),
              trailing: const Skeleton(width: 70, height: 32, borderRadius: 8),
            ),
          ),
        );
      },
    );
  }
}

/// A list of skeleton cards mimicking Booking items
class BookingListSkeleton extends StatelessWidget {
  const BookingListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Skeleton(width: 140, height: 20),
                      Skeleton(width: 70, height: 20, borderRadius: 8),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Skeleton(width: 100, height: 16),
                      Skeleton(width: 50, height: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Skeleton(width: 120, height: 16),
                  const SizedBox(height: 8),
                  const Skeleton(width: 200, height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
