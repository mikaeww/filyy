pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"

// The running jobs as cards in the lower right. The cards follow a model matched by job id: finished jobs leave,
// running ones update in place instead of every card being rebuilt ten times a second from Jobs.items.
Column {
    id: root

    function sync() {
        const items = Array.from(Jobs.items || []);
        const ids = items.map(job => job.id);
        for (let i = jobModel.count - 1; i >= 0; i--) {
            if (!ids.includes(jobModel.get(i).jobId))
                jobModel.remove(i);
        }
        for (const job of items) {
            const row = {
                jobId: job.id,
                kind: job.kind,
                jobState: job.state,
                count: job.count,
                folder: job.folder,
                current: job.current,
                done: job.done,
                total: job.total,
                rate: job.rate
            };
            let at = -1;
            for (let i = 0; i < jobModel.count; i++) {
                if (jobModel.get(i).jobId === job.id)
                    at = i;
            }
            if (at < 0)
                jobModel.append(row);
            else
                jobModel.set(at, row);
        }
    }

    spacing: Theme.space2
    z: 4

    ListModel {
        id: jobModel
    }

    Connections {
        function onChanged() {
            root.sync();
        }

        target: Jobs
    }

    Repeater {
        model: jobModel

        JobCard {}
    }
}
